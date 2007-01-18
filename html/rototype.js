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
  return R(s,e+1)
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

Enumerable = {
  mergeD : function(other){
    for (var i in other)
      this[i] = other[i]
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

  , byTag : function(tag, class){
    var t = this
    if (t == document || t == window)
      t = document
    var d = t.getElementsByTagName(tag).toA()
    if (class)
      return d.findAll(function(i){ return i.className.match(class) })
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


function Elem(tag,content,id,class,style) {
  var e = document.createElement(tag)
  if (content)
    if ((typeof content) == 'string')
      e.innerHTML = content
    else
      e.appendChild(content)
  if (class) e.className = class
  if (id) e.id = id
  if (style)
    if ((typeof style) == 'string')
      e.setAttribute("style", style)
    else
      e.style.mergeD(style)
  return e
}


function postForm(form, onSuccess, onFailure){
  var query = form.map(function(e){
    return (encodeURIComponent(e.name) + "=" + encodeURIComponent(e.value))
  }).join("&")+"&close_when_done"
  postQuery(form.action, query, onSuccess, onFailure)
}

function postQuery(url,query,onSuccess,onFailure){
  if (window.XMLHttpRequest) {
    var req = new XMLHttpRequest()
    req.open("POST", url, true)
    req.onreadystatechange = function() {
      if (req.readyState == 4 && req.status) {
        if (req.status == 200) {
          onSuccess(req)
        } else {
          onFailure(req)
        }
      }
    }
    req.send(query+"&inline")
  } else {
    window.open(url+"?"+query, '_blank')
  }
}
