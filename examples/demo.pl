#!/usr/bin/env perl 
use strict;
use warnings;
package Layout::Tickit;
use parent qw(Tickit::Widget);
use Tickit::Canvas;

use constant CLEAR_BEFORE_RENDER => 0;

sub new { my $class = shift; bless { @_ }, $class }
sub layout { shift->{layout} }

sub lines { 1 }
sub cols { 1 }
sub canvas { shift->{canvas} }
sub render {
	my $self = shift;
	my $win = $self->window or return;

	$self->canvas->retained(sub {
		my $ctx = shift;
		foreach my $item (@{$self->{layout}{ready}}) {
			$ctx->rect($item->{x}, $item->{y}, $item->{w}, $item->{h});
			$ctx->stroke(
				line_style => $item->{line_style} || 'single'
			);
		}
	});
	foreach my $item (@{$self->{layout}{ready}}) {
		next unless exists $item->{title};
		$win->goto($item->{y}, $item->{x} + 1);
		$win->print($item->{title});
	}
}
sub window_gained {
	my $self = shift;
	my ($win) = @_;
	$self->{canvas} = Tickit::Canvas->new(
		window => $win
	);
	$self->SUPER::window_gained($win, @_);
}

sub reshape {
	my $self = shift;
	my $win = $self->window;
	$self->canvas->clear;
	# $win->clear;
	$self->layout->{width} = $win->cols - 1;
	$self->layout->{height} = $win->lines - 1;
	$self->layout->render;
	$self->SUPER::reshape(@_);
}

sub window_lost {
	my $self = shift;
	my $win = shift;
	delete $self->{canvas};
	$self->SUPER::window_lost($win, @_)
}

package Layout;
use feature qw(say);
use POSIX qw(floor);
use List::Util qw(max min);

=pod

Outer width:
* Calculate from width
* Reduce by left+right margins
* Distribute by left_of / right_of

Inner width:
* reduce by 2 if border
* reduce by padding left+right

Outer height:
* Calculate from height
* Reduce by top+bottom margins
* Distribute by above/below 

Inner height:
* reduce by 2 if border
* reduce by padding top+bottom

=cut

use constant ALIGNMENTS => qw(above below left_of right_of top_align bottom_align left_align right_align);

sub new { my $class = shift; bless { width => 80, height => 80, @_ }, $class }
sub add {
	my $self = shift;
	my %args = @_;
	foreach my $direction (ALIGNMENTS) {
		next if ref($args{$direction});
		$args{$direction} = defined($args{$direction}) ? [ split ' ', $args{$direction} ] : [ ];
	}
	$self->{pending}{$args{id}} = \%args;
	$self;
}

sub render {
	my $self = shift;
	$self->{ready} = [];

	my @items;
	my @pending = map $self->{pending}{$_}, sort keys %{$self->{pending}};
	my @order;
	my %found;
	while(@pending) {
		my $next = shift @pending;
		my @deps = $self->find_deps($next);
		if(grep !exists $found{$_}, @deps) {
			push @pending, $next;
		} else {
			$found{$next->{id}} = $next;
			push @order, $next;
		}
	}
	say "Have items in this order:";
	say $_->{id} for @order;
	my $rw = $self->{width};
	my $rh = $self->{height};
	foreach my $item (@order) {
		say "Processing " . $item->{id};
		my $x = max 0, map $found{$_}{x} + $found{$_}{w}, @{$item->{right_of}};
		my $y = max 0, map $found{$_}{y} + $found{$_}{h}, @{$item->{below}};
		$x += $self->find_margin_left($item);
		$y += $self->find_margin_top($item);
		my $w = $self->find_width($item) - $x;
		$w -= $self->find_margin_right($item);
		my $h = $self->find_height($item) - $y;
		$h -= $self->find_margin_bottom($item);
		if(my @bottom = @{$item->{bottom_align}}) {
			$h = -$y + min map $found{$_}{y} + $found{$_}{h}, @bottom;
		}
		if(my @top = @{$item->{top_align}}) {
			my $add = -$y + max map $found{$_}{y} + $found{$_}{h}, @top;
			$y += $add;
			$h += $add;
		}
		say "At ($x, $y) size ($w, $h)";
		$item->{x} = $x;
		$item->{y} = $y;
		$item->{w} = $w;
		$item->{h} = $h;
		push @{$self->{ready}}, $item if $item->{w} > 1 && $item->{h} > 1;
	}
}

sub find_margin_left {
	my $self = shift;
	my $item = shift;
	$self->extract_measurement($item->{margin_left} || 0, $self->{width});
}

sub find_margin_top {
	my $self = shift;
	my $item = shift;
	$self->extract_measurement($item->{margin_top} || 0, $self->{height});
}

sub find_margin_right {
	my $self = shift;
	my $item = shift;
	$self->extract_measurement($item->{margin_right} || 0, $self->{width});
}

sub find_margin_bottom {
	my $self = shift;
	my $item = shift;
	$self->extract_measurement($item->{margin_bottom} || 0, $self->{height});
}

sub find_width {
	my $self = shift;
	my $item = shift;
	$self->extract_measurement($item->{width} || '100%', $self->{width});
}

sub find_height {
	my $self = shift;
	my $item = shift;
	$self->extract_measurement($item->{height} || '100%', $self->{height});
}

sub extract_measurement {
	my $self = shift;
	my $v = shift;
	my $max = shift;
	$v =~ s/\s+//g;
	if($v =~ /^(\d+(?:\.\d*)?)%$/) {
		$v = $1 * $max / 100;
	} elsif($v =~ /^(\d+)em$/) {
		$v = $1;
	}
	floor $v
}

sub find_deps {
	my $self = shift;
	my $item = shift;
	return map @$_, map $item->{$_} || [], ALIGNMENTS;
}

package main;
use Tickit::Widget::VBox;
use Tickit::Widget::Statusbar;
use Tickit::Widget::MenuBar;
use Tickit::Widget::Menu;
use Tickit::Widget::Menu::Item;

my $l = Layout->new(width => 80, height => 45);
$l->add(
	title => 'Left panel',
	id => 'send',
	border => 'round dashed single',
	width => '33%',
);
$l->add(
	title => 'Right panel',
	id => 'overview',
	right_of => 'send',
);
$l->render;
if(1) {
	use Tickit::Async;
	my $tickit = Tickit::Async->new;
	my $loop = IO::Async::Loop->new;
	my $vbox = Tickit::Widget::VBox->new;
	$vbox->add(Tickit::Widget::MenuBar->new(
		items => [
           Tickit::Widget::Menu::Item->new(
              name => "Exit",
              on_activate => sub { $tickit->stop }
           ),
		],
	));
	$vbox->add(
		Layout::Tickit->new(layout => $l),
		expand => 1
	);
	$vbox->add(Tickit::Widget::Statusbar->new(loop => $loop));
	$tickit->set_root_widget($vbox);
	$loop->add($tickit);
	$tickit->run;
}
