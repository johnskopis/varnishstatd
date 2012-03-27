#!/usr/bin/perl
use strict;
use Data::Dumper;
use LWP::UserAgent;
use HTTP::Cookies;
use HTTP::Headers;
use Getopt::Std;

my %opts;
getopt('H:o:P:',\%opts);

my ($host,$port,$perf) = ('localhost','8888',0);

$host = $opts{H} if $opts{H} ne "";
$port = $opts{P} if $opts{P} ne "";

my %oo = (
    client_conn_delta_1min => { w => 300, c=> 400 },
    client_conn_delta_5min => { w => 200, c=> 300 },
    client_conn_delta_15min => { w => 100, c=> 200 },
    client_drop_delta => { w => 5, c=> 10 },
    backend_conn_delta_1min => { w => 30, c=> 40 },
    backend_conn_delta_5min => { w => 20, c=> 30 },
    backend_conn_delta_15min => { w => 10, c=> 20 },
    backend_busy_delta => { w => 5, c => 10 },
    backend_fail_delta => { w => 5, c => 10 },
    backend_toolate_delta => { w => 5, c => 10 },
    backend_recycle_delta => { w => 5, c => 10 },
    backend_retry_delta => { w => 5, c => 10 },
    backend_unhealthy_delta => { w => 5, c => 10 },
    fetch_bad_delta => { w=>5, c=>10 },
    fetch_zero_delta => { w=>5, c=>10 },
    fetch_failed_delta => { w=>5, c=>10 },
    n_sess_mem_delta => { w=>5, c=>10 },
    n_sess_delta => { w=>5, c=>10 },
    n_wrk_queued_delta => { w=>5, c=>10 },
    n_wrk_drop_delta => { w=>5, c=>10 },
    sess_linger_delta => { w=>5, c=>10 },
    esi_errors_delta => { w=>5, c=>10 },
    esi_warnings_delta => { w=>5, c=>10 },
    accept_fail_delta => { w=>5, c=>10 },

);


foreach my $over(split(/\,/,$opts{o})) {
    my ($key,$w,$c) = split(/:/,$over);
    $oo{$key} = { 'w' => $w, 'c' => $c };
}



my $ua = LWP::UserAgent->new( 'requests_redirectable'=>[ 'GET', 'HEAD', 'POST'] );
my $cookie_jar = HTTP::Cookies->new( file => '/tmp/nagios/varnish_cookies.dat', autosave => 1);
$ua->cookie_jar($cookie_jar);
$ua->agent("Mozilla/5.0 (X11; U; SunOS sun4u; en-US; rv:1.0.1) Gecko/20020920 Netscape/7.0");


my @rc = (
	 [ 'GET',  'http://'.$host.':'.$port.'/' ],
);

my $i = 0;
my $ct;
my $ret = 0;
my %perf;
foreach (@rc) {
	my $req = HTTP::Request->new( @$_ ) || die $@;
	$req->header('Connection' => 'close');
    my $t1 = time;
	my $res = $ua->request($req);
    my $t2 = time;
    my $diff = $t2 - $t1;
    print "[ varnishstatsd";
    
    if ( $res->is_success && $diff <= 30) {
        print "(OK) ]";
        $ret |=0;
    } elsif ( $diff > 30 ) {
        print "(CRITICAL) ]";
        $ret |=2;
    } else  {
        print "(CRITICAL) ]";
        $ret |=2;
#request was not a success...probably a 500 status code
    }


    if ( $res->is_success ) {

        my %rr;

        %rr = map { split(/=/, $_) } split (/ /, $res->content);

        foreach ( keys %oo ) {
            if ( defined $rr{$_} ) {
                if ( $rr{$_} <= $oo{$_}->{w} ) {
                    print "[ $_ OK ]";
                    $ret |= 0;
                } elsif ( $rr{$_} >= $oo{$_}->{w} && $rr{$_} < $oo{$_}->{c} ) {
                    print "[ $_ WARN ($rr{$_}) ]";
                    $ret |= 1;
                } elsif ( $rr{$_} >= $oo{$_}->{c} ) {
                    print "[ $_ CRIT ($rr{$_}) ]";
                    $ret |= 2;
                }
            }
        }


        #print out perfdata
        print " |".$res->content,"\n" if $perf;
    }

}

if ($ret >= 3 ) {
    $ret = 2;
}

exit($ret);


