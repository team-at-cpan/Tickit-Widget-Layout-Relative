#!/usr/bin/env perl
use strict;
use warnings;
use Tickit::DSL;
use Tickit::Widget::Layout::Relative;
use Tickit::Style;

Tickit::Style->load_style(<<'EOF');
Decoration.horizontal {
 gradient-direction: 'horizontal';
}
Decoration.vertical {
 gradient-direction: 'vertical';
 start-fg: 255;
 end-fg: 232;
}
EOF

my $l = Tickit::Widget::Layout::Relative->new(width => 80, height => 45);
$l->add(
	Tickit::Widget::Entry->new,
	title  => 'Little panel',
	id     => 'send',
	border => 'round dashed single',
	width  => '33%',
	height => '5em',
);
$l->add(
	Tickit::Widget::Entry->new,
	title     => 'Another panel',
	id        => 'listen',
	below     => 'send',
	top_align => 'send',
	border    => 'round dashed single',
	width     => '33%',
	height    => '10em',
);
$l->add(
	Tickit::Widget::Entry->new,
	title        => 'Something on the right',
	id           => 'overview',
	right_of     => 'listen',
	bottom_align => 'listen',
	margin_top   => '1em',
	# width      => '67%',
	# margin_right => '3em',
);
$l->add(
	(my $tbl = Tickit::Widget::Table::Paged->new),
	title       => 'An area for details perhaps',
	id          => 'details',
	below       => 'listen overview',
	top_align   => 'listen overview',
	margin_left => '2em',
	border      => 'round single',
	width       => '100%',
	line_style  => 'thick',
);
$l->add(
	Tickit::Widget::Decoration->new(class => 'vertical'),
	id          => 'gofasterstripes',
	left_of     => 'details',
	below       => 'listen',
	border      => 'none',
);
{
	my $hb = Tickit::Widget::HBox->new(spacing => 1);
	$hb->add(Tickit::Widget::Decoration->new(class => 'horizontal'), expand => 1);
	$hb->add(Tickit::Widget::Static->new(text => 'Some title text here'));

	$l->add(
		$hb,
		id          => 'progtitle',
		above       => 'overview',
		right_of    => 'listen',
		border      => 'none',
	);
}
use Tickit::Widget::Table::Paged;
use Tickit::Widget::Static;
{
	$tbl->{row_offset} = 0;
	$tbl->add_column(
		label => 'Left',
		align => 'left',
		width => 8,
	);
	$tbl->add_column(
		label => 'Second column',
		align => 'centre'
	);
	$tbl->add_column(
		label => 'Widget column',
		type => 'widget',
		# We'll take care of creating our own widgets
		factory => sub {
			my $win = shift;
			my $w = Tickit::Widget::Static->new(text => 'new!');
			$w->set_window($win);
			$w
		},
		align => 'left'
	);
	$tbl->add_column(
		label => 'Right column',
		align => 'right'
	);

	$tbl->add_row(sprintf('line%04d', $_), sprintf("col2 line %d", $_), sub {
		shift->set_text(''.localtime);
	}, "third column!") for 1..200;
}
{
	use Fcntl qw(F_GETFL F_SETFL O_NONBLOCK);
	my $flags = fcntl(STDOUT, F_GETFL, 0)
		or die "Can't get flags for the socket: $!\n";
	fcntl(STDOUT, F_SETFL, $flags | O_NONBLOCK)
		or die "Can't set flags for the socket: $!\n";
}
if(1) {
	use Tickit::Async;
	my $tickit = Tickit::Async->new;
	my $vbox = Tickit::Widget::VBox->new;
	$vbox->add($l, expand => 1);
	$vbox->add(Tickit::Widget::Statusbar->new);
	$tickit->set_root_widget($vbox);
	$tickit->run;
}
