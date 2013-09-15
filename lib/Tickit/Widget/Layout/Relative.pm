package Tickit::Widget::Layout::Relative;
use strict;
use warnings;
use parent qw(Tickit::ContainerWidget);

=head1 NAME

Tickit::Widget::Layout::Relative - apply sizing to a group
of L<Tickit> widgets

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

# This does all the hard work
use Tickit::Layout::Relative;

use List::UtilsBy qw(extract_by);
use Scalar::Util qw(weaken refaddr);

use Tickit::Style;
use Tickit::RenderBuffer qw(LINE_SINGLE LINE_DOUBLE);

use constant CLEAR_BEFORE_RENDER => 0;
use constant WIDGET_PEN_FROM_STYLE => 1;

BEGIN {
	style_definition base =>
		title_fg              => 'white',
		frame_fg              => 'white',
		frame_linestyle       => 'rounded',
		focus_frame_fg        => 'green',
		focus_frame_linestyle => 'thick';
}

# There are a few unfortunate hoops to jump through to get
# rounded-corner rendering at the moment, but it tends to
# look neater:
use constant NORTH_SINGLE => Tickit::RenderBuffer->NORTH_SINGLE;
use constant SOUTH_SINGLE => Tickit::RenderBuffer->SOUTH_SINGLE;
use constant EAST_SINGLE => Tickit::RenderBuffer->EAST_SINGLE;
use constant WEST_SINGLE => Tickit::RenderBuffer->WEST_SINGLE;

=head1 METHODS

=cut

=head2 new

Instantiate a new layout. Takes a single named parameter:

=over 4

=item * layout - the optional L<Tickit::Layout::Relative> layout to use
for initial positioning, will create a new one if none is supplied

=back

=cut

sub new {
	my $class = shift;
	my %args = @_;
	my $layout = delete($args{layout}) || Tickit::Layout::Relative->new;
	my $self = $class->SUPER::new(%args);
	$self->{layout} = $layout;
	$self
}

=head2 layout

Returns the L<Tickit::Layout::Relative> instance.

=cut

sub layout { shift->{layout} }

=head2 lines

Returns the number of lines, carefully calculated using science.

=cut

sub lines { 1 }

=head2 cols

Number of columns.

=cut

sub cols { 1 }

=head2 add

Adds the given widget. Also takes a plethora of named options to help
decide where to put said widget and how it should be rendered:

=over 4

=item * title - a label to apply to this pane, default is blank

=item * id - an ID used for looking up widgets in an existing layout,
see L</widget_by_id> and L</window_by_id> for more details

=item * left_of - attempt to position this to the left of the pane
with the given ID

=item * right_of - try to arrange this widget on the right of the given
ID

=item * above - if we can, stick this widget above the given pane ID

=item * below - we want to be below the given ID

=item * top_align - try to align the top edge with the given widgets
(string containing space-separated list, or arrayref, of IDs)

=item * bottom_align - align the bottom edge with the given panes
(as top_align)

=item * left_align - we would like this things to be aligned on the
left (as top_align)

=item * right_align - we would like this things to be aligned on the
right (as top_align)

=item * margin - margin to apply around this widget, this is a measurement
(see L</MEASUREMENTS>).

=item * margin_left - left margin

=item * margin_right - right margin

=item * margin_top - top margin

=item * margin_bottom - bottom margin

=item * padding - padding to apply around this widget, this is a measurement
(see L</MEASUREMENTS>).

=item * padding_left - left padding

=item * padding_right - right padding

=item * padding_top - top padding

=item * padding_bottom - bottom padding

=item * width - how big we'd like to be, see L</MEASUREMENTS>

=item * height - how big we'd like to be, see L</MEASUREMENTS>

=back

Don't rely on the return value. It may change in future.

=cut

sub add {
	my $self = shift;
	my $w = shift;
	my %args = @_;
	$self->layout->add(widget => $w, %args);
	$self->SUPER::add($w);
}

=head2 render_to_rb

Renders the layout to the given L<Tickit::RenderBuffer>. Used internally.

=cut

sub render_to_rb {
	my $self = shift;
	my ($rb, $rect) = @_;
	my $win = $self->window or return;

	$rb->clear;
	my $linestyle = $self->get_style_values('frame_linestyle');
	my %corner;
	# Draw outlines for all contained widgets first
	my @ready = @{$self->{layout}{ready}};
	my ($focus) = extract_by { $_->{widget} && $self->{child_focus} && $_->{widget}->{window} && refaddr($_->{widget}->{window}) == $self->{child_focus} } @ready;
	push @ready, $focus if $focus;
	my $rectset = Tickit::RectSet->new;
	ITEM:
	foreach my $item (@ready) {
		next ITEM if ($item->{border} // '') eq 'none';

		# Tickit::Window
		my $child_focus = 0;
		if($item->{widget} && (my $widget_win = $item->{widget}->window)) {
			$child_focus = 1 if $widget_win->{focused} || $widget_win->{focused_child};
		}
		my $outline_pen = $self->get_style_pen($child_focus ? 'focus_frame' : 'frame');
		{
			local $SIG{__WARN__} = sub {};
			$rb->hline_at($item->{y}, $item->{x}, $item->{x} + $item->{w}, LINE_SINGLE, $outline_pen);
			$rb->hline_at($item->{y} + $item->{h}, $item->{x}, $item->{x} + $item->{w}, LINE_SINGLE, $outline_pen);
			$rb->vline_at($item->{y}, $item->{y} + $item->{h}, $item->{x}, LINE_SINGLE, $outline_pen);
			$rb->vline_at($item->{y}, $item->{y} + $item->{h}, $item->{x} + $item->{w}, LINE_SINGLE, $outline_pen);
		}

		$rectset->add(
			Tickit::Rect->new(
				top => $item->{y},
				left => $item->{x},
				lines => $item->{h} + 1,
				cols => $item->{w} + 1,
			)
		);

		# Rounded mode means we need to keep track of corner locations
		if($linestyle eq 'rounded') {
			$corner{join ',', $item->{y}, $item->{x}} = 1;
			$corner{join ',', $item->{y}, $item->{x} + $item->{w}} = 1;
			$corner{join ',', $item->{y} + $item->{h}, $item->{x}} = 1;
			$corner{join ',', $item->{y} + $item->{h}, $item->{x} + $item->{w}} = 1;
		}
	}

	# Overlay titles if we have them
	foreach my $item (@{$self->{layout}{ready}}) {
		next unless exists $item->{title};
		my $title_pen = $self->get_style_pen('title');
		$rb->text_at($item->{y}, $item->{x} + 1, ' ' . $item->{title} . ' ', $title_pen);
	}
	$self->{frame_rectset} = $rectset;

	# In rounded mode, replace corners where possible
	$self->render_corners($rb, $rect, map [ split /,/, $_ ], keys %corner) if $linestyle eq 'rounded';
}

{
my %override = (
	SOUTH_SINGLE | EAST_SINGLE, 0x256D,
	NORTH_SINGLE | EAST_SINGLE, 0x2570,
	SOUTH_SINGLE | WEST_SINGLE, 0x256E,
	NORTH_SINGLE | WEST_SINGLE, 0x256f,
);

=head2 render_corners

Render the corners. Purely for aesthetic reasons (rounded corners look
better than the usual square corners formed by vline/hline). Used internally.

=cut

sub render_corners {
	my $self = shift;
	my $rb = shift;
	my $rect = shift;
	my @corners = @_;

	CORNER:
	foreach my $corner (@corners) {
		my ($y, $x) = @$corner;
		my $cell = eval { $rb->_xs_getcell($y, $x) };
		next CORNER unless $cell && $cell->state == Tickit::RenderBuffer::LINE;
		my $mask = $cell->linemask;
		# Keep the same pen
		$rb->char_at($y, $x, $override{$mask}, $cell->pen) if exists $override{$mask};
	}
}
}

=head2 window_gained

When we get a window, we perform some unfortunate hacks to allow focus
notification. Most of this is highly likely to change in future.

=cut

sub window_gained {
	my $self = shift;
	my ($win) = @_;
	bless $win, 'Tickit::Widget::Layout::Relative::Window'; # aforementioned haxx
	$win->set_focus_callback(sub {
		weaken($self->{child_focus} = shift);
		if($self->{frame_rectset}) {
			$self->window->expose($_) for $self->{frame_rectset}->rects;
		} else {
			$self->redraw
		}
	});
	$self->SUPER::window_gained($win, @_);
	$win->{on_focus} = sub {
		warn "given focus\n";
		$self->redraw;
	};
}

=head2 reshape

Called when our main window changes shape. We recalculate layout to match
the new dimensions then update all child widgets accordingly.

=cut

sub reshape {
	my $self = shift;
	my $win = $self->window;
	$self->layout->{width} = $win->cols - 1;
	$self->layout->{height} = $win->lines - 1;
	$self->layout->render;
	foreach my $item (@{$self->{layout}{ready}}) {
		warn "Checking " . $item->{id} . " from ready list\n";
		next unless my $widget = $item->{widget};

		my $border_size = ($item->{border} eq 'none') ? 0 : 1;
		my $rect = Tickit::Rect->new(
			left  => $item->{x} + $border_size,
			top   => $item->{y} + $border_size,
			lines => $item->{h} - $border_size,
			cols  => $item->{w} - $border_size
		);
		warn "Item " . $item->{id} . " has $rect\n";

		# Reshape if we have one already
		if($widget->window) {
			$widget->window->change_geometry(
				$rect->top,
				$rect->left,
				$rect->lines,
				$rect->cols,
			) unless $widget->window->rect->equals($rect);
		} else {
			my $sub = $win->make_sub(
				$rect->top,
				$rect->left,
				$rect->lines,
				$rect->cols
			);
			$widget->set_window($sub);
		}
	}
	$self->SUPER::reshape(@_);
}

#sub focus_next {
#	my $self = shift;
#	$self->SUPER::focus_next(@_);
#	$self->redraw;
#}
#
sub children {
	my $self = shift;
	my @children = grep defined, map $_->{widget}, @{$self->layout->{ready}};
	@children
}

# i really want this to go away
package
	Tickit::Widget::Layout::Relative::Window;
use parent qw(Tickit::Window);

sub set_focus_callback {
	my $self = shift;
	$self->{focus_callback} = shift;
}
sub _focus_gained {
	my $self = shift;
	my $child = shift;
	$self->{focus_callback}->($child) if $child;
	$self->SUPER::_focus_gained($child, @_)
}

1;

