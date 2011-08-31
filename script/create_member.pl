#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use URI;
use Encode;
use Web::Scraper;
use Amon2::DBI;

my $url = 'http://www.ske48.co.jp/profile/list.php';

my $dbh =  Amon2::DBI->connect('dbi:mysql:ske:127.0.0.1:3306', 'root', '');

my %members;
my $ske = scraper {
    process '//div[@id="sectionMain"]/ul/li/dl/dd', 'members[]' => scraper {
        process 'a', 'link' => '@href';
        process 'a', 'name' => 'TEXT';
    };
};

my $detail = scraper { process 'div.detail>dl>dd>ul>li', 'nick_name' => 'TEXT' };

my @kenkyuusei = (
    'iguchi_shiori',
    'inuzuka_asana',
    'imade_mai',
    'uchiyama_mikoto',
    'kito_momona',
    'kobayashi_emiri',
    'saito_makiko',
    'matsumura_kaori',
    'mizuno_honoka',
);
my %kenkyuusei = map { $_ => 1 } @kenkyuusei;
my $list = $ske->scrape( URI->new($url) );
for my $member (@{ $list->{members} }) {

    my ($name) = "$member->{link}" =~ /\?id=(.*)$/;
    my $is_kenkyuusei = $kenkyuusei{ $name } ? 1 : 0;

    $dbh->insert('member', {
        'name'         => $name,
        'display_name' => $member->{name},
        'is_kenkyuusei'=> $is_kenkyuusei,
        'created_at'   => SQL::Interp::sql('NOW()'),
    });
}

