#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use URI;
use JSON;
use Encode;
use Web::Scraper;
use AnyEvent::HTTP;
use HTML::TreeBuilder::XPath;
use Amon2::DBI;
use Data::Dumper;

my $url = 'http://www.ske48.co.jp/blog/?writer=%s';
my $ske = scraper {
    process '//div[@id="sectionMain"]', 'blog' => scraper {
        process '//div[@class="unitBlog"]/h3', 'blog_update_time' => 'TEXT';
        process '//div[@class="box clearfix"]/h3', 'title' => 'TEXT';
        process '//div[@class="box clearfix"]', 'body' => 'TEXT';
    };
};

open my $fh, "<", "../../../environment.json" or die $!;
my $env = JSON::decode_json(join '', <$fh>);
my $dbh =  Amon2::DBI->connect(
    "dbi:mysql:ske:$env->{DOTCLOUD_DB_MYSQL_HOST}:$env->{DOTCLOUD_DB_MYSQL_PORT}",
    $env->{DOTCLOUD_DB_MYSQL_LOGIN},
    $env->{DOTCLOUD_DB_MYSQL_PASSWORD},
);

#--------------------------------------------------------------------------
my $members = $dbh->selectall_arrayref(
    q{ SELECT member.id, member.name FROM member WHERE is_kenkyuusei = 0 }, 
    { Columns => +{} }
); 

main() unless caller;

sub main {
    find_new_entry();
}

sub find_new_entry {
    
    my @data = ();
    my $cv = AnyEvent->condvar;
    for my $member (@{ $members }) {
   
        my $name     = $member->{name};
        my $blog_url = sprintf($url, $name);
    
        $cv->begin;
        http_get $blog_url, sub {
            my ($data, $headers) = @_;
            my $tree = HTML::TreeBuilder::XPath->new;
    
            $tree->parse( $data );
            my @items1 = $tree->findnodes( '//div[@id="sectionMain"]/div[@class="unitBlog"]/h3' );
            my @items2 = $tree->findnodes( '//div[@id="sectionMain"]/div[@class="unitBlog"]/div[@class="box clearfix"]/h3' );
            my @items3 = $tree->findnodes( '//div[@id="sectionMain"]/div[@class="unitBlog"]/div[@class="box clearfix"]' );
            
            my $blog_update_time = $items1[0]->as_text;
            my $title            = $items2[0]->as_text;
            my $body             = $items3[0]->as_text;
    
            my @blogs = $dbh->selectrow_array(q{
                 SELECT id 
                   FROM blog_update_history 
                  WHERE member_id = ? AND blog_update_time = ? 
            }, {}, ($member->{id}, $blog_update_time));
    
            # not updated
            if (@blogs) {
                $tree->delete;
                $cv->end;
                return;
            }
    
            # updated
            $dbh->insert('blog_update_history', {
                'member_id'        => $member->{id}, 
                 'title'            => $title,
                'body'             => $body,
                'blog_update_time' => $blog_update_time,
                'created_at'       => SQL::Interp::sql('NOW()'),
            });
    
            $tree->delete;
            $cv->end;
        };
    }
    
    $cv->recv;
}
__END__
