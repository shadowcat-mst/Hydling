package Hydling::ControlPort::Session;

use Mojo::JSON;
use Hydling::Base 'Mojo::EventEmitter';

has barfed => 0;
has running => sub { {} };

with 'Hydling::ControlPort::Role::HasHandlers';

sub dispatch ($self, @command) {
  return if $self->barfed;
  my $tag = (
    ($command[0]//'') =~ /^[A-Z]+[0-9]+$/
      ? shift(@command)
      : ''
  );
  return $self->barf(protocol => "Empty command")
    unless @command;
  my $type = shift @command;
  return $self->barf(protocol => "Command type should be a string")
    if ref($type);
  my $method = "_dispatch_${type}";
  return $self->barf(protocol => "Invalid command type ${type}")
    unless $self->can($method);
  return $self->barf(protocol => "Empty command args")
    unless @command;
  try {
    $self->$method($type, $tag, @command);
  } catch ($err) {
    return $self->barf(internal => $err);
  }
}

sub barf ($self, @barf) { $self->barfed(1)->emit(barf => @barf) }

sub send ($self, @send) { $self->emit(send => @send) }

sub _dispatch_call { shift->_request(@_) }
sub _dispatch_cast { shift->_request(@_) }
sub _dispatch_listen { shift->_request(@_) }
sub _dispatch_trap { shift->_request(@_) }

sub _dispatch_unlisten { shift->_cancel(@_) }
sub _dispatch_untrap { shift->_cancel(@_) }

sub _request_class ($self, $type) {
  my $class = "Hydling::ControlPort::${\ucfirst($type)}Request";
  state %loaded;
  $loaded{$class} ||= do { require join('/', split '::', $class).'.pm'; 1 };
  $class;
}

sub _request ($self, $type, $tag, $name, @args) {
  if (my $running = $self->running->{$tag}) {
    return $self->barf(protocol => "Duplicate use of tag $tag") if $tag;
    $running->awaitable->AWAIT_ON_READY(sub {
      $self->dispatch($type, $tag, $name, @args);
    });
    return;
  }
  $self->_request_class($type)->new(
    tag => $tag,
    name => $name,
    args => \@args,
    session => $self,
  )->dispatch;
  return;
}

sub _cancel ($self, $type, $tag, $name, @) {
  $type =~ s/^un//;
  if (my $running = $self->running->{join ':', $type, $name}) {
    $running->cancel;
  }
  return;
}

1;
