package Hydling::ControlPort::Handlers;

use Hydling::Class;

has [qw(call_handlers listen_handlers watch_handlers)] => sub { [ {}, [] ] };

sub _handler ($self, $op, $specifier, $code) {
  my $hconfig = $self->${\"${op}_handlers"};
  if (!ref($specifier)) {
    $hconfig->[0]{$specifier} = $code;
  } elsif (ref($specifier) eq 'Regexp') {
    push @{$hconfig->[1]}, [ $specifier, $code ];
  } else {
    die;
  }
  return;
}

sub lookup ($self, $op, $name) {
  my $hconfig = $self->${\"${op}_handlers"};
  if (my $code = $hconfig->[0]{$name)) { return $code }
  foreach my $entry (@{$hconfig->[1]}) {
    return $entry->[1] if $name =~ $entry->[0];
  }
  return undef;
}

sub call { shift->_handler(call => @_) }
sub listen { shift->_handler(listen => @_) }
sub watch { shift->_handler(watch => @_) }

1;
