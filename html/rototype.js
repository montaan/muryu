/*
  rototype.js - some javascript utils
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


function require(url) {
  var head = document.getElementsByTagName("head")[0]
  var scripts = head.getElementsByTagName("script")
  for(var i=0;i<scripts.length;i++){
    if (scripts[i].src == url) return false
  }
  var s = document.createElement("script")
  s.src = url
  head.appendChild(s)
  return true
}
require('json.js')
String.prototype.parseRawJSON = function(){
  if (this.length == 0) return undefined
  return eval('('+this+')')
}

function timed(f, msg) {
    var t = new Date().getTime()
    f()
    alert(msg + ": " + (new Date().getTime() - t))
}

function R(s, e){
  a = []
  for(var i=s; i<e; i++)
    a.push(i)
  return a
}

function Rg(s,e){
  var r = R(s,e)
  r.push(e)
  return r
}

function $S(selname)
{
  var sheets = document.styleSheets
  for (i=0; i<sheets.length; i++)
  {
    var rules = sheets[i].cssRules
    if (!rules) continue
    for (j=0; j<rules.length; j++)
      if (rules[j].selectorText == selname)
        return rules[j]
  }
  return null
}

function toggleCSSDisplay(selector) {
  var s = $S(selector)
  var d = s.style.display
  if (s.style.originalDisplay == undefined)
    s.style.originalDisplay = s.style.display
  if (d && d == 'none') {
    s.style.display = s.style.originalDisplay
  } else {
    s.style.display = 'none'
  }
}



Enumerable = {
  mergeD : function(other){
    for (var i in other)
      try{ this[i] = other[i] } catch(e) {}
    return this
  }

  , merge : function(other){
    var clone = new this.constructor()
    clone.mergeD(this)
    clone.mergeD(other)
    return clone
  }

  , without : function(elem){
    var clone = new this.constructor()
    delete clone[elem]
    return clone
  }

  , bind : function(f) {
    var a = arguments.toA().slice(1)
    var o = this
    if ((typeof f) == 'string') f = o[f]
    return function(){
      return f.apply(o, a.concat(arguments.toA()))
    }
  }

  , toA : function() {
    if ((typeof this.length) == 'number') {
      return this.map()
    } else  {
      return [this]
    }
  }

  , self : function() {
    return this
  }

  , reverse : function(){
    return this.toA().reverse()
  }

  , isEmpty : function(){
    return (this.length == 0)
  }

  , includes : function(obj){
    for(var i=0; i<this.length; i++)
      if (this[i] == obj) return true
    return false
  }

  , each : function(f){
    if (this.length != undefined) {
      for(var i=0; i<this.length; i++) f(this[i])
    } else {
      for(var i in this) f([i, this[i]])
    }
    return this
  }

  , map : function(f){
    var r = []
    if ((typeof f) == 'string') {
      this.each(function(e){
        r.push(e[f])
      })
    } else if (f) {
      this.each(function(e){
        r.push(f(e))
      })
    } else {
      this.each(function(e){
        r.push(e)
      })
    }
    return r
  }

  , eachWithIndex : function(f){
    var i = 0
    this.each(function(e){
      f(e,i)
      i++
    })
    return this
  }

  , mapWithIndex : function(f){
    var r = []
    this.eachWithIndex(function(e,i){
      r.push(f(e,i))
    })
    return r
  }

  , zip : function(other, f){
    if (f) {
      return this.mapWithIndex(function(e,i){
        return f(e, other[i])
      })
    } else {
      return this.mapWithIndex(function(e,i){
        return [e, other[i]]
      })
    }
  }

  , findAll : function(f){
    var rv = []
    this.each(function(e){ if(f(e)) rv.push(e) })
    return rv
  }

  , last : function(i){
    if (i == undefined) i = 1
    return this[this.length-i]
  }

  , deleteIf : function(f){
    var idx
    for(var i = 0; i<this.length; i++){
      if (f(this[i])) {
        this.splice(i,1)
        i--
      }
    }
    return this
  }

  , deleteAll : function(i){
    var idx
    while ((idx = this.indexOf(i)) > -1)
      this.splice(idx, 1)
    return this
  }
}


Element = {
  $ : function(id){
    if (this == document || this == window) {
      return document.getElementById(id)
    } else {
      if (!this.childNodes) return false
      var gc
      for(var j=0;j < this.childNodes.length;j++) {
        var cn = this.childNodes[j]
        if (cn.id == id) return cn
        if (gc = cn.$(id)) return gc
      }
      return false
    }
  }


  , show : function(){
    this.style.display = 'inherit'
  }

  , hide : function(){
    this.style.display = 'none'
  }

  , toggleDisplay : function(){
    if (!this.style.display)
      this.style.display = this.computedStyle().display
    if (this.style.display == 'none')
      this.show()
    else
      this.hide()
  }

  , computedStyle : function(){
    return document.defaultView.getComputedStyle(this, '')
  }

  , byTag : function(tag, klass){
    var t = this
    if (t == document || t == window)
      t = document
    var d = t.getElementsByTagName(tag).toA()
    if (klass)
      return d.findAll(function(i){ return i.className.match(klass) })
    else
      return d
  }

  , insertAfter : function(obj, ref) {
    return this.insertBefore(obj, ref.nextSibling)
  }

  , insertChild : function(obj) {
    if (this.firstChild)
      return this.insertBefore(obj, this.firstChild)
    else
      return this.appendChild(obj)
  }

  , detachSelf : function(obj) {
    return this.parentNode.removeChild(this)
  }

  , absoluteLeft : function() {
    this.checkAbsoluteCoordCache()
    return this.cachedAbsoluteLeft
  }

  , absoluteTop : function() {
    this.checkAbsoluteCoordCache()
    return this.cachedAbsoluteTop
  }

  , checkAbsoluteCoordCache : function() {
    if (!this.styleValid) {
      if (!this.styleMonitor) {
        this.styleMonitor = this.makeStyleMonitor()
        var obj = this
        while(obj && obj.offsetLeft != null) { // not very nice, adding monitors to parents
          obj.addEventListener("DOMAttrModified", this.styleMonitor, false)
          obj = obj.parentNode
        }
      }
      this.updateCachedAbsoluteCoords()
      this.styleValid = true
    }
  }
  
  , makeStyleMonitor : function() {
    var t = this
    return function(e){
      if (e.target == this && e.attrName == 'style') t.styleValid = false
    }
  }

  , updateCachedAbsoluteCoords : function() {
    var obj = this
    var l = 0
    var t = 0
    while(obj && obj.offsetLeft != null) {
      l += obj.offsetLeft
      t += obj.offsetTop
      obj = obj.parentNode
    }
    this.cachedAbsoluteLeft = l
    this.cachedAbsoluteTop = t
  }

  , calculateAbsoluteLeft : function() {
    var obj = this
    var l = 0
    while(obj.offsetLeft != null) {
      l += obj.offsetLeft
      obj = obj.parentNode
    }
    return l
  }

  , calculateAbsoluteTop : function() {
    var obj = this
    var l = 0
    while(obj.offsetTop != null) {
      l += obj.offsetTop
      obj = obj.parentNode
    }
    return l
  }

}


Object.prototype.inspect = function(o){
  m=[]
  for (i in o) m.push([i, o[i]].join(": "))
  return "{ " + m.join("\n  ") + " }"
}

Object.prototype.mergeD = Enumerable.mergeD
Object.prototype.mergeD(Enumerable)
Object.prototype.$ = Element.$
Object.prototype.byTag = Element.byTag
HTMLElement.prototype.mergeD(Element)

var or = Array.prototype.reverse
Array.prototype.mergeD(Enumerable)
Array.prototype.reverse = or

String.prototype.rjust = function(len, pad) {
  var fpad = ''
  if (!pad) pad = ' '
  for(var i=0; i < (len-this.length); i++)
    fpad = fpad.concat(pad)
  return this.replace(/^/, fpad)
}
String.prototype.ljust = function(len, pad) {
  var fpad = ''
  if (!pad) pad = ' '
  for(var i=0; i < (len-this.length); i++)
    fpad = fpad.concat(pad)
  return this.replace(/$/, fpad)
}


$ = Enumerable.$


function formatTime(msec) {
  var sec = msec / 1000
  var hour = parseInt(sec/3600)
  var min = parseInt(sec/60)
  sec = parseInt(sec) % 60
  if (sec < 10) sec = "0"+sec
  min = min % 60
  if (hour > 0 && min < 10) min = "0"+min
  return (hour>0 ? hour+":" : '') + min + ":" + sec
}

function guessLanguage() {
  return ( navigator.language || navigator.browserLanguage ||
           navigator.userLanguage || 'en-US' )
}

function makeEditable(elem, path, key, validator, title) {
  elem.className = elem.className + " editable"
  elem.title = (title || "Click to edit")
  elem.addEventListener("click", function(e){
    var input = Elem('input', null, null, null, null, {type:"text", value:" "})
    var cs = elem.computedStyle()
    input.style.mergeD(cs)
    input.style.minWidth = elem.offsetWidth + 'px'
    input.addEventListener("keypress", function(e){
      if ((e.charCode || e.keyCode) == 27) input.cancel()
    }, false)
    input.cancel = function(){
      input.parentNode.insertBefore(elem, input)
      input.detachSelf()
    }
    var sf = function(ev){
      if (input.iv) clearTimeout(input.iv)
      if (!input.parentNode) return // already detached
      var sendval = input.value
      if (validator)
        sendval = validator(input.value)
      if (sendval && input.value != elem.oldValue) {
        var oldval = elem.textContent
        var old_color = elem.style.color
        elem.innerHTML = input.value
        elem.style.color = 'red'
        postQuery(path, [[key, sendval]],
          function(res) {
            elem.style.color = old_color
          },
          function(res) {
            elem.innerHTML = oldval + " (edit failed: "+res.statusText+")"
            elem.style.color = old_color
          }
        )
      }
      input.cancel()
    }
    elem.parentNode.insertAfter(input, elem)
    elem.detachSelf()
    elem.oldValue = elem.textContent
    input.value = elem.textContent + " :) "
    input.value = elem.textContent
    input.addEventListener("blur", sf, false)
    input.addEventListener("change", sf, false)
    input.focus()
  }, false)
}

function Elem(tag, content, id, klass, style, config) {
  var e = document.createElement(tag)
  if (content) {
    if ((typeof content) == 'string') {
      e.innerHTML = content
    } else {
      e.appendChild(content)
    }
  }
  if (klass) e.className = klass
  if (id) e.id = id
  if (style) {
    if ((typeof style) == 'string') {
      e.setAttribute("style", style)
    } else {
      e.style.mergeD(style)
    }
  }
  if (config) e.mergeD(config)
  return e
}

Number.magnitudes = ['k', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y']
Number.mag = function(num, last, acc) {
  if (num < 1000)
    return num + last
  var mag_index = parseInt(Math.log(num) / Math.log(1000))
  return (num / Math.pow(1000, mag_index)).toFixed(acc) + this.magnitudes[mag_index-1] + last
}

function Text(txt) {
  return document.createTextNode(txt)
}

function postForm(form, onSuccess, onFailure){
  var query = []
  form.each(function(e){
    if (e.tagName == 'INPUT') {
      if (e.type != 'checkbox' || e.checked) {
        query.push([e.name, e.value])
      }
      return
    } else if (e.tagName == 'SELECT' && e.multiple) {
      e.options.findAll(function(opt){return opt.selected}).each(function(opt){
        query.push([opt.name, opt.value])
      })
      return
    }
    query.push([e.name, e.value])
  })
  postQuery(form.action, query, onSuccess, onFailure)
}

function postQuery(url,queryObj,onSuccess,onFailure){
  var query = queryObj
  if ((typeof queryObj) == 'object') {
    query = queryObj.map(function(kv){
      return encodeURIComponent(kv[0]) + "=" + encodeURIComponent(kv[1])
    }).join("&")
  }
  if (window.XMLHttpRequest) {
    var req = new XMLHttpRequest()
    req.onreadystatechange = function() {
      if (req.readyState == 4 && req.status) {
        if (req.status == 200) {
          onSuccess(req)
        } else {
          onFailure(req)
        }
      }
    }
    req.open("POST", url, true)
    req.send(query)
  } else {
    window.open(url+"?"+query, '_blank')
  }
}

function deJSON(json) {
  eval('var obj = ' + json)
  return obj
}

// Fancy form input creators for different data types.
Editors = {

  // Time picker
  time : function(name, value, args) {
    var cont = Elem('div', null, null, 'timeEditor')
    var nullVal = true
    if (!value) {
      value = new Date()
    } else {
      nullVal = false
    }
    var y = Editors.intInput('year', value.getYear()+1900)
    var m = Editors.limitedIntInput('month', value.getMonth()+1, [1, 12, 2])
    var d = Editors.limitedIntInput('day', value.getDate(), [1, 31, 2])
    d.validator = function(v){
      var ok = false
      try{ ok = (new Date([Math.abs(y.value%1000),m.value,v].join(' ')).getDate() == parseInt(v)) }
      catch(e) { ok = false}
      return ok
    }
    var h = Editors.limitedIntInput('hour', value.getHours(), [0, 23, 2])
    h.style.marginLeft = '10px'
    var min = Editors.limitedIntInput('minute', value.getMinutes(), [0, 59, 2])
    var s = Editors.limitedIntInput('second', value.getSeconds(), [0, 59, 2])
    var hid = Editors.hiddenInput(name)
    var tz = ({value: value.getTimezoneOffset() / 60})
    var updater = function(){
      hid.value = ([y.value, m.value, d.value].join("-") + ' ' +
                   [h.value, min.value, s.value].join(":") + ' ' +
                   (tz.value < 0 ? tz.value : '+'+tz.value))
    }
    if (nullVal) {
      hid.value = ''
    } else {
      updater()
    }
    var parts = [y,m,d,h,min,s]
    parts.each(function(f){
      f.addEventListener('change', updater, false)
      cont.appendChild(f)
    })
    cont.appendChild(hid)
    return cont
  },

  intInput : function(name, value) {
    var inp = Elem('input', null, null, 'intInput',
      {width: Math.max(value.toString().length, 2) * 8 + 'px'},
      {type:"text", size: value.toString().length, "name": name, "value": value})
    inp.addEventListener('change', function(e){
      if (inp.validator && !inp.validator(inp.value)) {
        inp.value = value
        e.preventDefault()
        e.stopPropagation()
        return
      }
      inp.value = parseInt(inp.value)
      if (isNaN(inp.value)) inp.value = value
    }, true)
    return inp
  },

  limitedIntInput : function(name, value, args) {
    var low = args[0]
    var high = args[1]
    var padding = args[2] || 0
    var inp = Elem('input', null, null, 'limitedIntInput',
      {width: Math.max(value.toString().length, 2) * 8 + 'px'},
      { type:"text", size: value.toString().length,
        "name": name, "value": value.toString().rjust(padding, '0'),
        "low": low, "high": high
      })
    inp.addEventListener('change', function(e){
      if (inp.validator && !inp.validator(inp.value)) {
        inp.value = value.toString().rjust(padding, '0')
        e.preventDefault()
        e.stopPropagation()
        return
      }
      var v = Math.max(inp.low, Math.min(inp.high, parseInt(inp.value)))
      if (isNaN(v)) v = value
      inp.value = v.toString().rjust(padding, '0')
    }, true)
    return inp
  },

  hiddenInput : function(name, value) {
    var inp = Elem('input', null, null, null, null,
      {type:"hidden", "name": name, "value": value})
    return inp
  },

  // Expanding textarea
  text : function(name, value) {
    var inp = Elem('textarea', value, null, 'textEditor', null,
      {name: name})
    return inp
  },

  // String
  string : function(name, value) {
    var inp = Elem('input', null, null, 'stringEditor', null,
      {type:"text", "name": name, "value": value})
    return inp
  },

  // One or several from a list of values
  list : function(name, value, args){
    var list_values = args[0]
    var pick_multiple = args[1]
    var list = Elem('div', null, null, 'listEditor')
    if (typeof value != 'object') value = [value]
    if (pick_multiple) {
      var ul = Elem('ul')
      list_values.each(function(lv){
        var d = Elem('li')
        var opt = Elem('input')
        opt.type = 'checkbox'
        opt.name = name
        opt.value = lv
        if (value) opt.checked = value.includes(lv)
        d.appendChild(opt)
        d.appendChild(Text(lv))
        ul.appendChild(d)
      })
      list.appendChild(ul)
    } else {
      var inp = Elem('select', null, null, null, null, {name: name})
      list_values.each(function(lv){
        var opt = Elem('option', lv)
        opt.value = lv
        if (value) opt.selected = value.includes(lv)
        inp.appendChild(opt)
      })
      list.appendChild(inp)
    }
    return list
  },

  // One or several from a list of values or a new value
  listOrNew : function(name, value, args) {
    var ls = Editors.list(name, value, args)
    ls.appendChild(Elem('p','+ ',null,'listOrNewSeparator'))
    ls.appendChild(Editors.string(name+'.new', ''))
    return ls
  },

  // Autocompleting text field
  autoComplete : function(name, value, complete_values) {
    var inp = Elem('input', null, null, 'autoCompleteEditor', null,
      {type:"text", "name": name, "value": value})
    return inp
  },

  // Map coordinates
  location : function(name, value) {
    var loc = Elem('div', null, null, 'locationEditor')
    var hid = Elem('input', null, null, null, null,
      {type:"hidden", "name": name, "value": value})
    loc.appendChild(hid)
    if (typeof GBrowserIsCompatible != 'undefined' && GBrowserIsCompatible()) {
      var txt = Elem('span', value)
      loc.appendChild(txt)
      var latlng = [ NaN ]
      if (value) {
        latlng = value.replace(/[)(]/g, '').split(",").map(parseFloat)
      }
      if (isNaN(latlng[0]) || isNaN(latlng[1])) latlng = [0.0, 0.0]
      loc.mapAttachNode = document.body
      var loaded = function() {
        var map_outer_cont = Elem('span', null, null, 'google_map',
          {display: 'block', position: 'absolute'})
        if (loc.mapLeft) map_outer_cont.style.left = loc.mapLeft
        if (loc.mapTop) map_outer_cont.style.top = loc.mapTop
        loc.mapAttachNode.appendChild(map_outer_cont)
        var map_cont = Elem('span', null, null, null,
          {width: '100%', height: '100%', display: 'block'})
        map_outer_cont.appendChild(map_cont)
        var map = new GMap2(map_cont)
        map.setCenter(new GLatLng(latlng[0], latlng[1]), 3)
        var marker = new GMarker(new GLatLng(latlng[0], latlng[1]), {draggable: true})
        map.addOverlay(marker)
        map.addControl(new GSmallZoomControl())
        map.addControl(new GMapTypeControl())
        var updateVal = function(pt) {
          hid.value = pt.toUrlValue()
          txt.innerHTML = '(' + pt.toUrlValue() + ')'
        }
        GEvent.addListener(map, 'click', function(ol, pt){
          if (!ol) marker.setPoint(pt)
          updateVal(marker.getPoint())
        })
        GEvent.addListener(marker, 'dragend', function(){
          updateVal(marker.getPoint())
        })
        map_cont.addEventListener("DOMMouseScroll", function(e){
          if (e.detail > 0 ) {
            map.zoomOut()
          } else {
            map.zoomIn()
          }
          e.stopPropagation()
          e.preventDefault()
        }, false)
        map_outer_cont.unloadMonitor = setInterval(function(){
          var o = loc
          while (o) {
            if (o == document.body) return
            o = o.parentNode
          }
          clearInterval(map_outer_cont.unloadMonitor)
          map_outer_cont.detachSelf()
          GUnload()
        },100)
      }
      loc.loadMonitor = setInterval(function(){
        var o = loc
        while (o) {
          if (o == document.body) {
            clearInterval(loc.loadMonitor)
            loaded()
            return
          }
          o = o.parentNode
        }
      },100)
    } else {
      hid.type = 'text'
    }
    return loc
  },

  // Valid URL
  url : function(name, value) {
    var inp = Elem('input', null, null, 'urlEditor', null,
      {type:"text", "name": name, "value": value})
    return inp
  }
}

Mouse = {
  left : 0,
  browserPatterns : [
      [/Safari/, 1],
      [/Firefox/, 0]
  ],
  
  detectButtons : function(){
    var pattern = this.browserPatterns.findAll(function(i){
      return navigator.userAgent.match(i[0])
    })[0]
    if (pattern) {
      this.left = pattern[1]
    }
  },

  normal : function(e) {
    return (e.button == this.left && !(e.ctrlKey || e.shiftKey || e.altKey))
  }
}

Mouse.detectButtons()
