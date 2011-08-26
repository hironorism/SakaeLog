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
get '/' => sub {
    my $c = shift;

#    my $member = $c->dbh->selectall_arrayref(q{ SELECT * FROM member }, { Columns => +{} });
    my $members = $c->dbh->selectall_arrayref(q{
        SELECT display_name, LENGTH(body) AS body_length 
          FROM member
          JOIN blog_update_history ON blog_update_history.member_id = member.id
         ORDER BY body_length DESC
    }, { Columns => +{} });

    my $name        = [ map { $_->{display_name} } @$members ];
    my $body_length = [ map { $_->{body_length} } @$members ];


    my $vars   = { 
        name        => $name,
        body_length => $body_length,
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

        var name = $.map([% name | json %], function(v,i) {
            return v.unescapeHTMLx();
        });
        var body_length = [% body_length | json %];

        // For horizontal bar charts, x an y values must will be "flipped"
        // from their vertical bar counterpart.
        var plot1 = $.jqplot('chart1', [ 
                body_length 
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
                    ticks: name,
                }
            }
        });
    });
    </script>
<style type="text/css">
.jqplot-yaxis-tick {
    width: 80px;
}
</style>
</head>
<body>
    SakaeLog

    <div id="chart1" style="height:1500px;width:500px; "></div>
</body>
</html>
