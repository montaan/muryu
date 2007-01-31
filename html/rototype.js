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
  if (d && d == 'none') {
    s.style.display = 'block'
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
    for(var i=0; i<this.length; i++){
      f(this[i])
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
    var obj = this
    var l = 0
    while(obj.offsetLeft != null) {
      l += obj.offsetLeft
      obj = obj.parentNode
    }
    return l
  }

  , absoluteTop : function() {
    var obj = this
    var l = 0
    while(obj.offsetLeft != null) {
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
Object.prototype.mergeD(Element)

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
  var query = form.map(function(e){
    return [e.name, e.value]
  })
  postQuery(form.action, query, onSuccess, onFailure)
}

function postQuery(url,queryObj,onSuccess,onFailure){
  var query = queryObj
  if ((typeof queryObj) == 'object') {
    query = queryObj.map(function(kv){
      return escape(kv[0]) + "=" + escape(kv[1])
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
  time : function(name, value) {
  },

  // Expanding textarea
  text : function(name, value) {
  },

  // One or several from a list of values
  list : function(name, value, list_values, pick_multiple, separator) {
  },

  // One or several from a list of values or a new value
  listOrNew : function(name, value, list_values, pick_multiple, separator) {
  },

  // Autocompleting text field
  autoComplete : function(name, value) {
  },

  // Map coordinates
  coordinates : function(name, value) {
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
