package Hydling::ControlPort;

use Mojo::IOLoop;
use Hydling::Base -strict;

sub server ($class, %config) {
  state $loaded = do { require Hydling::ControlPort::Server; 1 };
  Hydling::ControlPort::Server->new(config => \%config)->start;
}

1;
