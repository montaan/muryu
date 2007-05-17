/*
  desk.js - a window system for JavaScript
  Copyright (C) 2007  Ilmari Heikkinen

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

  http://www.gnu.org/copyleft/gpl.html
*/


Desk = {}

var libs = [
  'session', 'windows_utils', 'metadata', 'button',
  'windowmanager', 'windows', 'panel', 'applets',
  'taskbar'
]
var head = document.getElementsByTagName('head')[0]
libs.each(function(lib){
  var el = document.createElement('script')
  el.src = 'scripts/desk_js/' + lib + '.js'
  head.appendChild(el)
})

