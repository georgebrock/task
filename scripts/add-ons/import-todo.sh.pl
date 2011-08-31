#! /usr/bin/perl
################################################################################
## taskwarrior - a command line task list manager.
##
## Copyright 2006 - 2011, Paul Beckingham, Federico Hernandez.
## All rights reserved.
##
## This program is free software; you can redistribute it and/or modify it under
## the terms of the GNU General Public License as published by the Free Software
## Foundation; either version 2 of the License, or (at your option) any later
## version.
##
## This program is distributed in the hope that it will be useful, but WITHOUT
## ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
## FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
## details.
##
## You should have received a copy of the GNU General Public License along with
## this program; if not, write to the
##
##     Free Software Foundation, Inc.,
##     51 Franklin Street, Fifth Floor,
##     Boston, MA
##     02110-1301
##     USA
##
################################################################################

use strict;
use warnings;
use Time::Local;

# Priority mappings.
my %priority_map = (
  'a' => 'H', 'b' => 'M', 'c' => 'L', 'd' => 'L', 'e' => 'L', 'f' => 'L',
  'g' => 'L', 'h' => 'L', 'i' => 'L', 'j' => 'L', 'k' => 'L', 'l' => 'L',
  'm' => 'L', 'n' => 'L', 'o' => 'L', 'p' => 'L', 'q' => 'L', 'r' => 'L',
  's' => 'L', 't' => 'L', 'u' => 'L', 'v' => 'L', 'w' => 'L', 'x' => 'L',
  'y' => 'L', 'z' => 'L');

my @tasks;
while (my $todo = <>)
{
  my $status = 'pending';
  my $priority = '';
  my $entry = '';
  my $end = '';
  my @projects;
  my @contexts;
  my $description = '';
  my $due = '';

  # pending + pri + entry
  if ($todo =~ /^(\([A-Z])\)\s(\d{4}-\d{2}-\d{2})\s(.+)$/i)
  {
    ($status, $priority, $entry, $description) = ('pending', $1, epoch ($2), $3);
  }

  # pending + pri
  elsif ($todo =~ /^(\([A-Z])\)\s(.+)$/i)
  {
    ($status, $priority, $description) = ('pending', $1, $2);
  }

  # pending + entry
  elsif ($todo =~ /^(\d{4}-\d{2}-\d{2})\s(.+)$/i)
  {
    ($status, $entry, $description) = ('pending', epoch ($1), $2);
  }

  # done + end + entry
  elsif ($todo =~ /^x\s(\d{4}-\d{2}-\d{2})\s(\d{4}-\d{2}-\d{2})\s(.+)$/i)
  {
    ($status, $end, $entry, $description) = ('completed', epoch ($1), epoch ($2), $3);
  }

  # done + end
  elsif ($todo =~ /^x\s(\d{4}-\d{2}-\d{2})\s(.+)$/i)
  {
    ($status, $end, $description) = ('completed', epoch ($1), $2);
  }

  # done
  elsif ($todo =~ /^x\s(.+)$/i)
  {
    ($status, $description) = ('completed', $1);
  }

  # pending
  elsif ($todo =~ /^(.+)$/i)
  {
    ($status, $description) = ('pending', $1);
  }

  # Project
  @projects = $description =~ /\+(\S+)/ig;

  # Contexts
  @contexts = $description =~ /\@(\S+)/ig;

  # Due
  $due = epoch ($1) if $todo =~ /\sdue:(\d{4}-\d{2}-\d{2})/i;

  # Map priorities
  $priority = $priority_map{lc $priority} if $priority ne '';

  # Pick first project
  my $first_project = shift @projects;

  # Compose the JSON
  my $json = '';
  $json .= "{\"status\":\"${status}\"";
  $json .= ",\"priority\":\"${priority}\""     if defined $priority && $priority ne '';
  $json .= ",\"project\":\"${first_project}\"" if defined $first_project && $first_project ne '';
  $json .= ",\"entry\":\"${entry}\""           if $entry ne '';
  $json .= ",\"end\":\"${end}\""               if $end ne '';
  $json .= ",\"due\":\"${due}\""               if $due ne '';

  if (@contexts)
  {
    $json .= ",\"tags\":\"" . join (',', @contexts) . "\"";
  }

  $json .= ",\"description\":\"${description}\"}";

  push @tasks, $json;
}

print "[\n", join (",\n", @tasks), "\n]\n";
exit 0;

################################################################################
sub epoch
{
  my ($input) = @_;

  my ($y, $m, $d) = $input =~ /(\d{4})-(\d{2})-(\d{2})/;
  return timelocal (0, 0, 0, $d, $m-1, $y-1900);
}

################################################################################

__DATA__
(A) @phone thank Mom for the meatballs
(B) +GarageSale @phone schedule Goodwill pickup
+GarageSale @home post signs around the neighborhood
@shopping Eskimo pies
(A) Call Mom
Really gotta call Mom (A) @phone @someday
(b)->get back to the boss
2011-03-02 Document +TodoTxt task format
(A) 2011-03-02 Call Mom
(A) Call Mom 2011-03-02
(A) Call Mom +Family +PeaceLoveAndHappiness @iphone @phone
X 2011-03-03 Call Mom
xylophone lesson
x 2011-03-02 2011-03-01 Review Tim's pull request +TodoTxtTouch @github
