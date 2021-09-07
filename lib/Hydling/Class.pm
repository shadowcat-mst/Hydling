package Hydling::Class;

use curry;
use Import::Into;
use Mojo::Base -strict, -signatures;

sub import ($me, $base = '-base') {
  Feature::Compat::Try->import::into(1);
  Carp->import::into(1, 'croak');
  Safe::Isa->import::into(1);
  Mojo::Base->import::into(1, $base, -signatures, -async_await);
  warnings->import::into(1, FATAL => 'uninitialized');
  warnings->unimport::out_of(1, 'once');
  experimental->import::into(1, qw(declared_refs refaliasing));
}

1;
