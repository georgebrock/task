#! /usr/bin/env perl
################################################################################
## taskwarrior - a command line task list manager.
##
## Copyright 2006-2014, Paul Beckingham, Federico Hernandez.
##
## Permission is hereby granted, free of charge, to any person obtaining a copy
## of this software and associated documentation files (the "Software"), to deal
## in the Software without restriction, including without limitation the rights
## to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
## copies of the Software, and to permit persons to whom the Software is
## furnished to do so, subject to the following conditions:
##
## The above copyright notice and this permission notice shall be included
## in all copies or substantial portions of the Software.
##
## THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
## OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
## FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
## THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
## LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
## OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
## SOFTWARE.
##
## http://www.opensource.org/licenses/mit-license.php
##
################################################################################

use strict;
use warnings;
use Test::More tests => 26;

# Ensure environment has no influence.
delete $ENV{'TASKDATA'};
delete $ENV{'TASKRC'};

# Create the rc file.
if (open my $fh, '>', 'op.rc')
{
  print $fh "data.location=.\n",
            "confirmation=no\n";
  close $fh;
  ok (-r 'op.rc', 'Created op.rc');
}

# Setup: Add a task
qx{../src/task rc:op.rc add one   due:yesterday priority:H 2>&1};
qx{../src/task rc:op.rc add two   due:tomorrow  priority:M 2>&1};
qx{../src/task rc:op.rc add three               priority:L 2>&1};
qx{../src/task rc:op.rc add four                           2>&1};

# Test the '<' operator.
my $output = qx{../src/task rc:op.rc ls due.before:today 2>&1};
like   ($output, qr/one/,   'ls due.before:today --> one');
unlike ($output, qr/two/,   'ls due.before:today --> !two');
unlike ($output, qr/three/, 'ls due.before:today --> !three');
unlike ($output, qr/four/,  'ls due.before:today --> !four');

$output = qx{../src/task rc:op.rc ls 'due < today' 2>&1};
like   ($output, qr/one/,   'ls due < today --> one');
unlike ($output, qr/two/,   'ls due < today --> !two');
unlike ($output, qr/three/, 'ls due < today --> !three');
unlike ($output, qr/four/,  'ls due < today --> !four');

$output = qx{../src/task rc:op.rc ls priority.below:H 2>&1};
unlike ($output, qr/one/,   'ls priority.below:H --> !one');
like   ($output, qr/two/,   'ls priority.below:H --> two');
like   ($output, qr/three/, 'ls priority.below:H --> three');
like   ($output, qr/four/,  'ls priority.below:H --> four');

$output = qx{../src/task rc:op.rc ls 'priority < H' 2>&1};
unlike ($output, qr/one/,   'ls priority < H --> !one');
like   ($output, qr/two/,   'ls priority < H --> two');
like   ($output, qr/three/, 'ls priority < H --> three');
like   ($output, qr/four/,  'ls priority < H --> four');

$output = qx{../src/task rc:op.rc ls 'description < t' 2>&1};
like   ($output, qr/one/,   'ls description < t --> one');
unlike ($output, qr/two/,   'ls description < t --> !two');
unlike ($output, qr/three/, 'ls description < t --> !three');
like   ($output, qr/four/,  'ls description < t --> four');

$output = qx{../src/task rc:op.rc 'urgency < 10.0' ls 2>&1};
unlike ($output, qr/one/,   'ls description < 10 --> !one');
unlike ($output, qr/two/,   'ls description < 10 --> !two');
like   ($output, qr/three/, 'ls description < 10 --> three');
like   ($output, qr/four/,  'ls description < 10 --> four');

# Cleanup.
unlink qw(pending.data completed.data undo.data backlog.data op.rc);
ok (! -r 'pending.data'   &&
    ! -r 'completed.data' &&
    ! -r 'undo.data'      &&
    ! -r 'backlog.data'   &&
    ! -r 'op.rc', 'Cleanup');

exit 0;

