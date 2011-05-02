////////////////////////////////////////////////////////////////////////////////
// task - a command line task list manager.
//
// Copyright 2006 - 2011, Paul Beckingham, Federico Hernandez.
// All rights reserved.
//
// This program is free software; you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation; either version 2 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program; if not, write to the
//
//     Free Software Foundation, Inc.,
//     51 Franklin Street, Fifth Floor,
//     Boston, MA
//     02110-1301
//     USA
//
////////////////////////////////////////////////////////////////////////////////

#include <View.h>
#include <text.h>
#include <utf8.h>
#include <main.h>

////////////////////////////////////////////////////////////////////////////////
View::View ()
: _width (0)
, _left_margin (0)
, _header (0)
, _odd (0)
, _even (0)
, _intra_padding (1)
, _intra_odd (0)
, _intra_even (0)
, _extra_padding (0)
, _extra_odd (0)
, _extra_even (0)
, _truncate (0)
, _lines (0)
{
}

////////////////////////////////////////////////////////////////////////////////
//   |<---------- terminal width ---------->|
//
//         +-------+  +-------+  +-------+
//         |header |  |header |  |header |
//   +--+--+-------+--+-------+--+-------+--+
//   |ma|ex|cell   |in|cell   |in|cell   |ex|
//   +--+--+-------+--+-------+--+-------+--+
//   |ma|ex|cell   |in|cell   |in|cell   |ex|
//   +--+--+-------+--+-------+--+-------+--+
// 
//   margin        - indentation for the whole table
//   extrapadding  - left and right padding for the whole table
//   intrapadding  - padding between columns
//
//
// Layout Algorithm:
//   - Height is irrelevant
//   - Determine the usable horizontal space for N columns:
//
//       usable = width - ma - (ex * 2) - (in * (N - 1))
//
//   - Look at every column, for every task, and determine the minimum and
//     maximum widths.  The minimum is the length of the largest indivisible
//     word, and the maximum is the full length of the value.
//   - If there is sufficient terminal width to display every task using the
//     maximum width, then do so.
//   - If there is insufficient terminal width to display every task using the
//     minimum width, then there is no layout solution.  Error.
//   - Otherwise there is a need for column wrapping.  Calculate the overage,
//     which is the difference between the sum of the minimum widths and the
//     usable width.
//   - Start by using all the minimum column widths, and distribute the overage
//     among all columns, one character at a time, while the column width is
//     less than the maximum width, and while there is overage remaining.
//
// Note: a possible enhancement is to proportionally distribute the overage
//       according to average data length.
//
std::string View::render (std::vector <Task>& data, std::vector <int>& sequence)
{
  // Determine minimal, ideal column widths.
  std::vector <int> minimal;
  std::vector <int> ideal;

  std::vector <Column*>::iterator i;
  for (i = _columns.begin (); i != _columns.end (); ++i)
  {
    // Headers factor in to width calculations.
    int global_min = utf8_length ((*i)->getLabel ());
    int global_ideal = global_min;

    std::vector <Task>::iterator d;
    for (d = data.begin (); d != data.end (); ++d)
    {
      // Determine minimum and ideal width for this column.
      int min;
      int ideal;
      (*i)->measure (*d, min, ideal);

      if (min > global_min)     global_min = min;
      if (ideal > global_ideal) global_ideal = ideal;
    }

    minimal.push_back (global_min);
    ideal.push_back (global_ideal);
  }

  // Sum the minimal widths.
  int sum_minimal = 0;
  std::vector <int>::iterator c;
  for (c = minimal.begin (); c != minimal.end (); ++c)
    sum_minimal += *c;

  // Sum the ideal widths.
  int sum_ideal = 0;
  for (c = ideal.begin (); c != ideal.end (); ++c)
    sum_ideal += *c;

  // Calculate final column widths.
  int overage = _width
              - _left_margin
              - (2 * _extra_padding)
              - ((_columns.size () - 1) * _intra_padding);

  std::vector <int> widths;
  if (sum_ideal <= overage)
    widths = ideal;
  else if (sum_minimal > overage)
    throw std::string ("There is not enough horizontal width to display the results.");
  else
  {
    widths = minimal;
    overage -= sum_minimal;

    // Spread 'overage' among columns where width[i] < ideal[i]
    while (overage)
    {
      for (int i = 0; i < _columns.size () && overage; ++i)
      {
        if (widths[i] < ideal[i])
        {
          ++widths[i];
          --overage;
        }
      }
    }
  }

  // Compose column headers.
  int max_lines = 0;
  std::vector <std::vector <std::string> > headers;
  for (int c = 0; c < _columns.size (); ++c)
  {
    headers.push_back (std::vector <std::string> ());
    _columns[c]->renderHeader (headers[c], widths[c], _header);

    if (headers[c].size () > max_lines)
      max_lines = headers[c].size ();
  }

  // Output string.
  std::string out;
  _lines = 0;

  // Render column headers.
  std::string left_margin = std::string (_left_margin, ' ');
  std::string extra       = std::string (_extra_padding, ' ');
  std::string intra       = std::string (_intra_padding, ' ');

  std::string extra_odd   = _extra_odd.colorize  (extra);
  std::string extra_even  = _extra_even.colorize (extra);
  std::string intra_odd   = _intra_odd.colorize  (intra);
  std::string intra_even  = _intra_even.colorize (intra);

  for (int i = 0; i < max_lines; ++i)
  {
    out += left_margin + extra;

    for (int c = 0; c < _columns.size (); ++c)
    {
      if (c)
        out += intra;

      if (headers[i].size () < max_lines - i)
        out += _header.colorize (std::string (widths[c], ' '));
      else
        out += headers[c][i];
    }

    out += extra + "\n";
    ++_lines;
  }

  // Compose, render columns, in sequence.
  std::vector <std::vector <std::string> > cells;
  std::vector <int>::iterator s;
  for (int s = 0; s < sequence.size (); ++s)
  {
    max_lines = 0;

    // Apply color rules to task.
    Color rule_color;
    autoColorize (data[s], rule_color);

    // Alternate rows based on |s % 2|
    bool odd = (s % 2) ? true : false;
    Color row_color = odd ? _odd : _even;
    row_color.blend (rule_color);

    for (int c = 0; c < _columns.size (); ++c)
    {
      cells.push_back (std::vector <std::string> ());
      _columns[c]->render (cells[c], data[s], widths[c], row_color);

      if (cells[c].size () > max_lines)
        max_lines = cells[c].size ();
    }

    for (int i = 0; i < max_lines; ++i)
    {
      out += left_margin + (odd ? extra_odd : extra_even);

      for (int c = 0; c < _columns.size (); ++c)
      {
        if (c)
          out += (odd ? intra_odd : intra_even);

        if (i < cells[c].size ())
          out += cells[c][i];
        else
          out += row_color.colorize (std::string (widths[c], ' '));
      }

      out += (odd ? extra_odd : extra_even) + "\n";
      ++_lines;
    }

    cells.clear ();
  }

  return out;
}

////////////////////////////////////////////////////////////////////////////////
