#!/usr/bin/env perl
use strict;
use warnings;
use URI;
use URI::QueryParam;
use Encode;
use File::Spec;
use File::Basename qw(dirname);
use Web::Scraper;
use Email::Send;
use Email::MIME;
use Data::Dumper;

my $from = 'hoge@example.com';
my $to   = 'foo@example.com';
my $url = 'http://shop.ske48.co.jp/';
my $file_path = File::Spec->catfile(dirname(__FILE__), '../../data/new_item.dat');


main() unless caller;

sub main {

    my $item = find_new_item();
    return unless $item;
    
    send_mail($item);
}


sub find_new_item {

    my $item = scraper {
        process '//div[@id="Information"]/dl[@class="Information_data"]/dd/a', 'link' => '@href';
    }->scrape( URI->new($url) );

    my $id = $item->{link}->query_param('id');
    my $ret = update_id($id);  
    return unless $ret;
 
    my $detail = scraper {
        process '//div[@id="Information"]/dl[@class="Information_data"]/dd', 'text' => 'TEXT';
    }->scrape( $item->{link} );

    return $detail->{text};
}

sub update_id {
    my ($id) = @_;

    my $data = '';
    if (-e $file_path) {
        open my $fh, '+<', $file_path or die "$file_path:$!";
        $data = join '', <$fh>;
        close $fh;
        unlink $file_path;
    }

    open my $fh, '>', $file_path or die "$file_path:$!";
    print ${fh} $id;
    close $fh;

    return if $data eq $id;
    return $id; 
}

sub send_mail {
    my ($body) = @_;

    my $message = Email::MIME->create(
        header => [
            From => $from,
            To   => $to,
            subject => 'SKE SHOP NEW ITEM INFO',
        ],
        body => encode('iso-2022-jp', $body),
    );

    my $send = Email::Send->new({mailer => 'SMTP' });
    $send->send($message->as_string);
}
