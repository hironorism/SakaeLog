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

__PACKAGE__->load_plugins('DBI');

# put your configuration here
sub config {
    +{
        'DBI' => [
            'dbi:mysql:ske:localhost:3306',
            'root',
            '',
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
        value => [ map { $_->{number_of_characters}  } @$res ],
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
        value => [ map { $_->{number_of_updates} } @$res ],
    };
}

#-----------------------------------------------------------------------------------------------------

# daily
get '/{date:([0-9]{4}/[0-9]{2}/[0-9]{2})?}' => sub {
    my ($c, $args) = @_;

use Data::Dumper;warn Dumper $args;
    my $start = strftime('%Y-%m-%d 02:00:00', localtime());
    my $end   = strftime('%Y-%m-%d 02:00:00', localtime( time() + 60*60*24 ));

    my @params = ($start, $end);
    my $number_of_characters = get_chacters_ranking($c->dbh, @params);
    my $number_of_updates    = get_updates_ranking($c->dbh, @params);

    my $vars   = {
        number_of_characters => $number_of_characters,
        number_of_updates    => $number_of_updates,
    };

    return $c->render('index.tt', $vars);
};


# monthly
get '/:year/:month' => sub {
    my ($c, $args) = @_;

use Data::Dumper;warn Dumper $args;
    my $start = strftime('%Y-%m-%d 02:00:00', localtime());
    my $end   = strftime('%Y-%m-%d 02:00:00', localtime( time() + 60*60*24 ));

    my @params = ($start, $end);
    my $number_of_characters = get_chacters_ranking($c->dbh, @params);
    my $number_of_updates    = get_updates_ranking($c->dbh, @params);

    my $vars   = {
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

__DATA__

@@ index.tt
<!doctype html>
<html>
<head>
    <met charst="utf-8">
    <title>SakaeLog</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <script language="javascript" type="text/javascript" src="/static/js/dist/jquery.min.js"></script>
    <script language="javascript" type="text/javascript" src="/static/js/dist/jquery.jqplot.min.js"></script>
    <script type="text/javascript" src="/static/js/dist/plugins/jqplot.barRenderer.min.js"></script>
    <script type="text/javascript" src="/static/js/dist/plugins/jqplot.categoryAxisRenderer.min.js"></script>
    <script type="text/javascript" src="/static/js/dist/plugins/jqplot.pointLabels.min.js"></script>

    <link rel="stylesheet" type="text/css" href="/static/css/jquery.jqplot.css" />

    <script type="text/javascript">
    String.prototype.unescapeHTMLx = function () {
        var temp = document.createElement("div");
        temp.innerHTML = this;
        var result = temp.childNodes[0].nodeValue;
        temp.removeChild(temp.firstChild);
        return result;
    }

    $(document).ready(function(){

        var name1 = $.map([% number_of_characters.name | json %], function(v,i) {
            return v.unescapeHTMLx();
        });

        var value1 = $.map([% number_of_characters.value | json %], function(v,i) {
            return parseInt(v);
        });

        var plot1 = $.jqplot('chart1', [ 
               value1 
            ], {
            seriesDefaults: {
                renderer:$.jqplot.BarRenderer,
                pointLabels: { show: true, location: 'e', edgeTolerance: -15 },
                shadowAngle: 130,
                rendererOptions: {
                    barDirection: 'horizontal'
                },
            },
            axes: {
                yaxis: {
                    renderer: $.jqplot.CategoryAxisRenderer,
                    ticks: name1,
                }
            }
        });

        var name2 = $.map([% number_of_updates.name | json %], function(v,i) {
            return v.unescapeHTMLx();
        });

        var value2 = $.map([% number_of_updates.value | json %], function(v,i) {
            return parseInt(v);
        });
        var plot2 = $.jqplot('chart2', [ 
               value2 
            ], {
            seriesDefaults: {
                renderer:$.jqplot.BarRenderer,
                pointLabels: { show: true, location: 'e', edgeTolerance: -15 },
                shadowAngle: 130,
                rendererOptions: {
                    barDirection: 'horizontal'
                },
            },
            axes: {
                yaxis: {
                    renderer: $.jqplot.CategoryAxisRenderer,
                    ticks: name2,
                }
            }
        });
    });
    </script>
<style type="text/css">
.jqplot-yaxis-tick {
    width: 80px;
}
.chart2 {
    position: absolute;
    position-left: 600px;
}
</style>
</head>
<body>

    文字数<br />
    <div id="chart1" style="height:1500px;width:500px; "></div>

    更新回数<br />
    <div id="chart2" style="height:1500px;width:500px; "></div>
</body>
</html>
