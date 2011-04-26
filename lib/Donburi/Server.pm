package Donburi::Server;
use strict;
use warnings;

use Twiggy::Server;
use AnyEvent;
use AnyEvent::IRC::Client;
use YAML;
use Text::Xslate;
use Scope::Container;

use Donburi::Dispatcher;

sub run {
    my $conf = shift;

    my $container = start_scope_container();

    my $config = YAML::LoadFile($conf);
    scope_container('config', $config);

    my $tx = Text::Xslate->new(
        path      => ['.'],
        cache_dir => '/tmp/.donburi',
        cache     => 1,
    );
    scope_container('xslate', $tx);

    my $cv = AnyEvent->condvar;
    my $irc = AnyEvent::IRC::Client->new;
    $irc->reg_cb(
        connect => sub {
            my ($irc, $err) = @_;
            if (defined $err) {
                warn "connect error: $err\n";
                $cv->send;
            }
        },
    );

    $irc->connect(
        $config->{irc}->{server},
        $config->{irc}->{port},
        { nick => $config->{irc}->{nick} }
    );
    $irc->send_srv("JOIN", '#kan');
    $irc->send_chan('#kan', 'NOTICE', '#kan', 'hello');

    scope_container('irc', $irc);

    my $twg = Twiggy::Server->new(
        host => $config->{http}->{server},
        port => $config->{http}->{port},
    );
    my $dispatcher = Donburi::Dispatcher->new;
    $twg->register_service(sub {
        my $env = shift;

        return $dispatcher->dispatch($env);
    });

    $cv->recv;
    $irc->disconnect;
}

1;
