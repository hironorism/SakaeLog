#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use URI;
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

my $dbh = Amon2::DBI->connect('dbi:mysql:ske:127.0.0.1:3306', 'root', '');
#--------------------------------------------------------------------------
my $members = $dbh->selectall_arrayref(q{ SELECT member.id, member.name FROM member }, undef, { Columns => +{}});

main() unless caller;

sub main {
    find_new_entry();
}

sub find_new_entry {
    
    my @data = ();
    my $cv = AnyEvent->condvar;
    for my $member (@{ $list->{members} }) {
        my ($name)            = $member->{link} =~ /\?writer=(.*)$/;
        my $blog_update_time  = $member->{blog_update_time};
        next if ($name eq 'secretariat' || $name eq 'kenkyuusei');
    
        $cv->begin;
        http_get "$member->{link}", sub {
            my ($data, $headers) = @_;
            my $tree = HTML::TreeBuilder::XPath->new;
    
            $tree->parse( $data );
            my @items   = $tree->findnodes( '//div[@class="box clearfix"]' );
            my $length  = length( decode_utf8 $items[0]->as_text );
    
            my $info = $dbh->selectrow_hashref(q{ SELECT id FROM member WHERE name = ? }, undef, ($name) );
    
            my @blogs = $dbh->selectrow_array(q{
                 SELECT id 
                   FROM blog_update_history 
                  WHERE member_id = ? AND blog_update_time = ? 
            }, undef, ($info->{id}, $blog_update_time));
    
            # not updated
            if (@blogs) {
                $tree->delete;
                $cv->end;
                return;
            }
    
            # updated
            $dbh->insert('blog_update_history', {
                'member_id'        => $info->{id}, 
                'length'           => $length,
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
