use strict;
use warnings;
use utf8;
use File::Spec;
use File::Basename;
use lib File::Spec->catdir(dirname(__FILE__), 'extlib', 'lib', 'perl5');
use lib File::Spec->catdir(dirname(__FILE__), 'lib');
use Plack::Builder;
use Amon2::Lite;
use Text::Xslate::Util qw(mark_raw);
use JSON;
use Data::Rmap qw();
use Scalar::Util qw(blessed);
use POSIX qw(strftime); 
use Time::Piece;
use Time::Local;
$ENV{TZ} = 'Asia/Tokyo';

__PACKAGE__->load_plugins('DBI');

my $file = -e "/home/dotcloud/environment.json" ? "/home/dotcloud/environment.json" : "development.json";
open my $fh, $file or die $!;
my $env = JSON::decode_json(join '', <$fh>);

# put your configuration here
sub config {
    +{
        'DBI' => [
            "dbi:mysql:ske:$env->{DOTCLOUD_DATA_MYSQL_HOST}:$env->{DOTCLOUD_DATA_MYSQL_PORT}",
            $env->{DOTCLOUD_DATA_MYSQL_LOGIN},
            $env->{DOTCLOUD_DATA_MYSQL_PASSWORD},
        ],
        'Text::Xslate' => {
            function => {
                json => sub {
                      my $hashref = shift;
                      Data::Rmap::rmap_to {
                          Data::Rmap::cut($_) if blessed $_;
                          return if ref $_;
                          $_ = Text::Xslate::unmark_raw(Text::Xslate::html_escape($_))
                      } Data::Rmap::ALL, $hashref;
                      my $json = JSON->new->ascii->encode($hashref);
                      my $bs = '\\';
                      $json =~ s!/!${bs}/!g;
                      $json =~ s!<!${bs}u003c!g;
                      $json =~ s!>!${bs}u003e!g;
                      $json =~ s!&!${bs}u0026!g;
                      Text::Xslate::mark_raw($json);
                },
            },
        },
    }
}

#-----------------------------------------------------------------------------------------------------
sub get_chacters_ranking {
    my ($dbh, @params) = @_;

    my $res = $dbh->selectall_arrayref(q{
        SELECT display_name, SUM( LENGTH(body) ) AS number_of_characters 
          FROM member
          JOIN blog_update_history ON blog_update_history.member_id = member.id
         WHERE blog_update_time >= ? AND blog_update_time < ?
         GROUP BY member.id 
         ORDER BY number_of_characters ASC
    }, { Columns => +{} }, @params);

    return {
        name  => [ map { $_->{display_name} } @$res ],
        value => [ map { $_->{number_of_characters} || 0  } @$res ],
    };
}

sub get_updates_ranking {
    my ($dbh, @params) = @_;

    # 更新数ランキング
    my $res = $dbh->selectall_arrayref(q{
        SELECT display_name, COUNT( member.id ) AS number_of_updates
          FROM member
          JOIN blog_update_history ON blog_update_history.member_id = member.id
         WHERE blog_update_time >= ? AND blog_update_time < ?
         GROUP BY member.id 
         ORDER BY number_of_updates ASC
    }, { Columns => +{} }, @params);

    return {
        name  => [ map { $_->{display_name} } @$res ],
        value => [ map { $_->{number_of_updates} || 0 } @$res ],
    };
}

sub date_info {
    my $time = scalar @_ == 3 ? timelocal(0,0,0,$_[2],$_[1]-1,$_[0]-1900) : time();

    my $tp = localtime( $time );
    my $next_month_tp = $tp->add_month(1);
    my $prev_month_tp = $tp->add_month(-1);

    my $next_day_tp = $tp + 60*60*24;
    my $prev_day_tp = $tp - 60*60*24;

    return {
        # 次の月/前の月 
        next_month_tp       =>
        next_month_of_year  =>
        next_month_of_month =>
        prev_month_tp       =>
        prev_month_of_year  =>
        prev_month_of_month =>
    
        # 次の日/前の日
        next_day_tp         =>
        next_day_of_year    =>
        next_day_of_month   =>
        next_day_of_day     =>
        prev_day_tp         =>
        prev_day_of_year    =>
        prev_day_of_month   =>
        prev_day_of_day     =>
    
        current_tp          =>
        current_year        =>
        current_month       =>
        current_day         =>
    };
}

#-----------------------------------------------------------------------------------------------------

# daily
get '/{date:([0-9]{4}/[0-9]{2}/[0-9]{2})?}' => sub {
    my ($c, $args) = @_;
    my ($year, $month, $day) = split m!/!, $args->{date};
warn "$year/$month/$day";

    my $time  = $args->{date} ? timelocal(0,0,0,$day,$month-1,$year-1900) : time(); 

    my $current_tp = localtime( $time );
    my $next_tp    = $current_tp + 60*60*24;
    my $prev_tp    = $current_tp - 60*60*24;

    my $start_date = $current_tp->strftime('%Y-%m-%d 02:00:00');
    my $end_date   = $next_tp->strftime('%Y-%m-%d 02:00:00');

    my @params = ($start_date, $end_date);
    my $number_of_characters = get_chacters_ranking($c->dbh, @params);
    my $number_of_updates    = get_updates_ranking($c->dbh, @params);

    my $vars   = {
        next_date    => $next_tp->ymd('/'),
        prev_date    => $prev_tp->ymd('/'),
        current_date => strftime('%Y-%m-%d %H:%M:%S', localtime()),
        start_date   => $start_date,
        end_date     => $end_date,
        number_of_characters => $number_of_characters,
        number_of_updates    => $number_of_updates,
    };

    return $c->render('index.tt', $vars);
};


# monthly
get '/{year:[0-9]{4}}/{month:[0-9]{2}}' => sub {
    my ($c, $args) = @_;

    my $year  = $args->{year};
    my $month = $args->{month} + 1;
    if ($args->{month}  == 12) {
        $year  = $args->{year} + 1;
        $month = 1;
    }
    my $time  = timelocal(0,0,0,1,$args->{month}-1,$args->{year}-1900); 
    my $start = sprintf("%04d-%02d-01 02:00:00", $args->{year}, $args->{month});
    my $end   = sprintf("%04d-%02d-01 02:00:00", $year, $month);

    my @params = ($start, $end);
    my $number_of_characters = get_chacters_ranking($c->dbh, @params);
    my $number_of_updates    = get_updates_ranking($c->dbh, @params);

    my $vars   = {
        current_date => strftime('%Y-%m-%d %H:%M:%S', localtime()),
        start_date => $start,
        end_date   => $end,
        number_of_characters => $number_of_characters,
        number_of_updates    => $number_of_updates,
    };

    return $c->render('index.tt', $vars);

};

#-----------------------------------------------------------------------------------------------------

# for your security
__PACKAGE__->add_trigger(
    AFTER_DISPATCH => sub {
        my ( $c, $res ) = @_;
        $res->header( 'X-Content-Type-Options' => 'nosniff' );
    },
);

# load plugins
use HTTP::Session::Store::File;
__PACKAGE__->load_plugins(
    'Web::CSRFDefender',
    'Web::HTTPSession' => {
        state => 'Cookie',
        store => HTTP::Session::Store::File->new(
            dir => File::Spec->tmpdir(),
        )
    },
);

builder {
    enable 'Plack::Middleware::Static',
        path => qr{^(?:/static/|/robot\.txt$|/favicon.ico$)},
        root => File::Spec->catdir(dirname(__FILE__));
    enable 'Plack::Middleware::ReverseProxy';

    __PACKAGE__->to_app();
};
