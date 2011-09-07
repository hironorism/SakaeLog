#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use URI;
use JSON;
use Encode;
use Web::Scraper;
use List::Util qw/max min/;
use Amon2::DBI;
use Data::Dumper;

my $url = 'http://www.ske48.co.jp/blog/?writer=kenkyuusei';
my $ske = scraper {
    process '//div[@id="sectionMain"]', 'blog' => scraper {
        process '//div[@class="unitBlog"]/h3', 'blog_update_time' => 'TEXT';
        process '//div[@class="box clearfix"]/h3', 'title' => 'TEXT';
        process '//div[@class="box clearfix"]', 'body' => 'TEXT';
    };
};

my $file = -e "/home/dotcloud/environment.json" ? "/home/dotcloud/environment.json" : "../../development.json";
open my $fh, "<", $file or die $!;
my $env = JSON::decode_json(join '', <$fh>);
my $dbh =  Amon2::DBI->connect(
    "dbi:mysql:ske:$env->{DOTCLOUD_DATA_MYSQL_HOST}:$env->{DOTCLOUD_DATA_MYSQL_PORT}",
    $env->{DOTCLOUD_DATA_MYSQL_LOGIN},
    $env->{DOTCLOUD_DATA_MYSQL_PASSWORD},
);
my $kenkyuusei = $dbh->selectall_hashref(q{
    SELECT member.id, member.name, blog_rotation.sort, blog_rotation.turn
      FROM member 
      JOIN blog_rotation ON member.id = blog_rotation.member_id
}, 'sort');

#--------------------------------------------------------------------------

main() unless caller;

sub main {
    find_new_entry();
}

sub find_new_entry {
    my $list = $ske->scrape( URI->new($url) );

    my $title = $list->{blog}{title};   
    (my $body = $list->{blog}{body}) =~ s/^$list->{blog}{title}//;
    my $blog_update_time = $list->{blog}{blog_update_time};

    my ($max)  = max keys %$kenkyuusei;
    my ($last) = grep { $kenkyuusei->{$_}{turn} } keys %$kenkyuusei;
    my $next = (!$last || $last == $max) ? 1 : $last + 1;
    my $next_member = $kenkyuusei->{ $next }; 

    my @member_ids = ();
    my $bind_params = join ',', map { push @member_ids, $kenkyuusei->{$_}{id}; '?' } %$kenkyuusei;
    my @blogs = $dbh->selectrow_array(qq{
         SELECT id 
           FROM blog_update_history 
          WHERE member_id IN ($bind_params) AND blog_update_time = ? 
    }, {}, (@member_ids, $blog_update_time));

    # not updated
    if (@blogs) {
        warn 'not updated.';
        return;
    }

    # updated
    $dbh->insert('blog_update_history', {
        'member_id'        => $next_member->{id}, 
        'title'            => $title,
        'body'             => $body,
        'blog_update_time' => $blog_update_time,
        'created_at'       => SQL::Interp::sql('NOW()'),
    });

    $dbh->do(q{
        UPDATE blog_rotation SET turn = CASE 
                    WHEN sort = ? AND turn = 1 THEN 0 
                    WHEN sort = ? AND turn = 0 THEN 1 
                ELSE turn END,
                updated_at = CASE 
                    WHEN sort IN (?,?) THEN NOW()  
                ELSE updated_at END
    }, {}, ($last, $next, $last, $next));
}
__END__
