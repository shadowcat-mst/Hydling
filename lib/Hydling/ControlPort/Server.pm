pakcage Hydling::ControlPort::Server;

use Hydling::ControlPort;:Session;
use Mojo::IOLoop::Server;
use Hydling::Base;

has config => undef;
has listener => sub ($self) {
  Mojo::IOLoop::Server->new
                      ->listen($self->config)
                      ->on(accept => $self::curry::weak::accept);
};

with 'Hydling::ControlPort::Role::HasHandlers';

sub start ($self) { $self->listener->start; $self }
sub stop ($self) { $self->listener->stop; $self }

sub accept ($self, $loop, $stream, $id) {
  my $session = Hydling::ControlPort;:Session->new(
    handlers => $self->handlers,
  );
  my $buf = '';
  $stream->on(read => sub ($self, $read) {
    $buf .= $read;
    while ($buf =~ s/^(.*)\r?\n//ms) {
      my $line = $1;
      my @command = do {
        try {
          @{decode_json($line)};
        } catch ($err) {
          return $self->barf(protocol => "Couldn't decode message: $err");
        }
      };
      $session->dispatch(@command);
      last if $self->barfed;
    }
    return
  });
  $session->on(send => sub ($self, @send) {
    my $data = do {
      try {
        encode_json(\@send)."\n";
      } catch ($err) {
        return $self->barf(internal => "Couldn't encode message: $err");
      }
    };
    $stream->write($data);
    return;
  });
  $session->on(barf => sub ($self, @barf) {
    try {
      $stream->write(
        encode_json([ barf => @barf ])."\n",
        $stream->curry::close,
      );
    } catch ($err) {
      $stream->close;
    }
    return;
  });
  return;
}

1;
