#!/usr/bin/perl -w
use strict;

use Getopt::Long;
use Data::Dumper;

my %OPTS;
GetOptions(
    \%OPTS,
    "login=s",
    "password=s",
    "url=s",
);

foreach (qw/login password url/) {
    die usage() unless $OPTS{$_};
}

my $ua = agent->new;

$OPTS{url} =~ /https?:\/\/(.+?)\// or die "strange url";
my $domain = $1;
$ua->cookies->set_cookie("0", "ispmgr4" , "sirius:en:0", "/", $domain);

my $results = $ua->post(
    $OPTS{'url'},
    {
        username => $OPTS{'login'},
        password => $OPTS{'password'},
        theme => 'sirius',
        lang => 'en',
        func => 'auth'
    }
);

my $cookie = fetch_js_cookie($results);
$ua->cookies->set_cookie("0", "ispmgr4" , $cookie, "/", $domain);
#$ua->get($OPTS{url});

print Dumper( );
my @domains  = fetch_domain_list($ua->get($OPTS{url} . "?func=domain"));
foreach(@domains) {
    my $domain = $_->{'domain'};
    -d './zones/' || mkdir './zones';
    open(my $zone, "> ./zones/$domain") or die "$!";
    print $zone fetch_domain_parameters(
        $ua->get($OPTS{url} . "?func=domain.edit&elid=help4children.ru&operafake=90")
    );
    print $zone "=========== ZONE =============\n";
    print $zone fetch_zone(
        $ua->get($OPTS{'url'} . "?func=domain.sublist&elid=$domain")
    );
    close($zone);
}

sub fetch_zone { (join "\n", $_[0] =~ /tblstat\[\"(.+?)\"\]/gs) . "\n" }

sub fetch_domain_list {
    my $content = shift;

    $content =~ /var va=\[(.+?)\];/s;
    my $domains_1 = $1;

    return map {
        my @a = split ',';
        @a = map { s/["\s\r]+//gs; $_ } @a;
        { 'domain' => $a[0], 'id' => $a[2] }
    }
    ( $domains_1 =~ /\[(.+?)\]/gs );
}

sub fetch_domain_parameters {
    my $inputs = fetch_inputs(shift);
qq~Name: $inputs->{name}
IP: $inputs->{ip}
MX: $inputs->{mx}
NS: $inputs->{ns}
~
}

sub fetch_inputs {
    my $inputs = {};
    map {
        /name="(.+?)"/;
        my $n = $1;
        /value="(.*?)"/;
        my $v = $1;
        $inputs->{$n} = $v;
    } $_[0] =~ /(<input.+?>)/g;
    return $inputs;
}

sub fetch_js_cookie {
=off
document.cookie = binary.substr(binary.lastIndexOf('/')+1)+'4=sirius:en:1569343807; path=/; expires=Wednesday, 18-May-33 03:33:20 GMT';
                        document.location = "/manager/ispmgr";</script>
=cut
    my $content = shift;
    $content =~ /\+1\)\+\'4\=(\w+:\w+:\d+); path=/ or die "cookie not found";
    return $1;
}
sub usage {
    qq~$0 -l <login> -p <password> -u <url to ispmanager>\n~;
}

{
package agent;
use strict;
use LWP::UserAgent;
use HTTP::Cookies;
use Data::Dumper;

sub new { bless { ua => $_[0]->_init_ua }, $_[0] }

sub _init_ua {
    my $self = shift;
    my $ua = LWP::UserAgent->new(
        max_redirect => 0,
        keep_alive => 1,
        agent => 'Mozilla/4.0 (compatible; MSIE 6.1; Windows XP; .NET CLR 1.1.4322; .NET CLR 2.0.50727)'
    );

    my $cookie_jar = HTTP::Cookies->new;

    $ua->timeout(10);
    $ua->env_proxy;
    $ua->cookie_jar( $cookie_jar );
    $ua->default_header('Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');
    $ua->default_header('Accept-Language' => 'ru,en-us;q=0.7,en;q=0.3');
    $ua->default_header('Accept-Encoding' => 'gzip,deflate');
    $ua->default_header('Accept-Charset' => 'windows-1251,utf-8;q=0.7,*;q=0.7');
    $ua->default_header('Keep-Alive' => '300');
    $ua->default_header('Connection' => 'keep-alive');
    return $ua;
}

sub ua { shift->{ua} }
sub response { shift->{response} }
sub is_response_ok {
    my $self = shift;
    return ($self->response->is_success or $self->response->code == 302);
}
sub content { shift->response->decoded_content }

sub last_url {
    $_[0]->{'last_url'} = $_[1] if $_[1];
    $_[0]->{'last_url'};
}

sub _set_refer {
    $_[0]->ua->default_header('Referer' => $_[0]->last_url)
        if $_[0]->last_url;
}

sub _do_request {
    my $self = shift;
    my $url = shift or die "no url";
    my $method = lc(shift);
    $method ||= 'get';
    my $params = shift;
    $self->_set_refer;
    $self->{'response'} = $params 
        ? $self->ua->$method($url, $params)
        : $self->ua->$method($url);
    if ($self->is_response_ok) {
            return $self->content;
    }
    $self->("_throw_${method}_error")($url, $params);
}

sub _throw_get_error {
    my $self = shift;
    my $url = shift;
    die "Error due gettings url `$url`: "
        . $self->response->status_line;
}

sub _throw_post_error {
    my $self = shift;
    my $url = shift;
    my $post = shift;
    die     "Error due gettings POST http request URL: `$url`\n" .
        "POST: " . Dumper($post) . "\n" .
        "RESPONSE: " . Dumper($self->response) . "\n" .
        $self->response->status_line;
}


sub get { 
    my ($self, $uri) = @_;
    return $self->_do_request($uri);
}

sub cookies { shift->ua->cookie_jar }

sub post {
    my $self = shift;
    my $uri = shift;
    return $self->_do_request($uri, 'post', @_);
}

}
=off
username:v1643739
password:21hCwXwykEtzgHl
theme:sirius
lang:en
func:auth
