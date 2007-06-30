// Copies all of obj's properties to this.
Object.forceExtend = function(dest,src){
  for(var i in src)
    try{ dest[i] = src[i] } catch(e) {}
  return dest
}
// Retrieves the named object.
// E.g. Object.retrieve('MusicPlayer.playlist')
Object.retrieve = function(object_path) {
  return object_path.split(".").inject(
    window,
    function(o,n){return o[n]}
  )
}

// Create a new element with tagName tag, with content (string or node), set
// CSS className to klass, merge given style with new element style and merge
// attributes with the element.
//
// Returns the created element.
E = function(tag, content, id, klass, style, attributes){
  var e = document.createElement(tag)
  if (typeof content == 'string')
    e.innerHTML = content
  else if (content)
    e.appendChild(content)
  if (id) e.id = id
  if (klass) e.className = klass
  if (style) Object.forceExtend(e.style, style)
  if (attributes) Object.forceExtend(e, attributes)
  return e
}
Elem = E

A = function(href, content, id, klass, style, attributes){
  var a = E('a', content, id, klass, style, attributes)
  a.href = href
  return a
}

T = function(text) {
  return document.createTextNode(text)
}

// Find the key with the minimum value according to iterator.
Hash.prototype.minKey = function(iterator) {
  var result, minKey, tmp
  iterator = (iterator || Prototype.K)
  this.each(function(value, index) {
    tmp = iterator(value, index)
    if (result == undefined || tmp < result) {
      result = tmp
      minKey = value[0]
    }
  })
  return minKey
}

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

// Delete the first appearance of elem from the array.
// Returns true if elem was found, false otherwise.
Array.prototype.deleteFirst = function(elem) {
  var i = this.indexOf(elem)
  if (i < 0) return false
  this.splice(i, 1)
  return true
}
Array.prototype.isEmpty = function() {
  return (this.length == 0)
}

Number.magnitudes = ['k', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y']
Number.mag = function(num, last, acc) {
  if (num < 1000)
    return num + last
  var mag_index = parseInt(Math.log(num) / Math.log(1000))
  return Tr.formatNumber((num / Math.pow(1000, mag_index)).toFixed(acc) + this.magnitudes[mag_index-1] + last)
}

Object.formatTime = function(msec) {
  var sec = msec / 1000
  var hour = parseInt(sec/3600)
  var min = parseInt(sec/60)
  sec = parseInt(sec) % 60
  if (sec < 10) sec = "0"+sec
  min = min % 60
  if (hour > 0 && min < 10) min = "0"+min
  return (hour>0 ? hour+":" : '') + min + ":" + sec
}

/**
  Simple translation system.

  Translate by doing Tr(key[, args, ...])

  Add translations by doing Tr.getLanguage(language)[key] = translation

  If the translation is a function, it'll be called (in context of
  Tr.translations[language]) and the result returned.
  Otherwise the translation will be returned as is.

  E.g.
    Tr.getLanguage('en-US')['MyApp.Welcome'] = 'Howdy, pardner.'
    Tr.getLanguage('en-US')['MyApp.Goodbye'] = 'See ya, stranger.'
    Tr.addTranslations('en-GB', {
      'MyApp.Welcome' : function(firstname, surname) {
        return 'Ah! How good of you to be here, my dear '+surname+'!'
      }
    })

    Tr.language = 'en-GB'

    Tr('MyApp.Welcome', 'John', 'Watson')
    // "Ah! How good of you to be here, my dear Watson!"

    Tr('MyApp.Goodbye', 'John', 'Watson')
    // "See ya, stranger."
*/
function Tr(key) {
  var lang = Tr.translations[Tr.language]
  if ( !(lang && lang[key]) )
    lang = Tr.translations[Tr.defaultLanguage]
  var translation = lang[key] || key
  if (typeof translation == 'function')
    return translation.apply(lang, $A(arguments).slice(1))
  return translation + $A(arguments).slice(1).join(" ")
}
Tr.formatNumber = function(num) {
  return num.replace(/\./, Tr('Number.decimalSeparator'))
}
Tr.getLanguage = function(lang) {
  if (!Tr.translations[lang]) Tr.translations[lang] = {}
  return Tr.translations[lang]
}
Tr.addTranslations = function(lang, translations) {
  return Object.extend(Tr.getLanguage(lang), translations)
}
Tr.guessLanguage = function() {
  return ( navigator.language ||
           navigator.browserLanguage ||
           navigator.userLanguage ||
           Tr.defaultLanguage )
}
Tr.defaultLanguage = 'en-US'
Tr.language = Tr.guessLanguage()
Tr.translations = new Hash()
Tr.translations[Tr.defaultLanguage] = new Hash()
Tr.addTranslations('en-US', {
  'Number.decimalSeparator' : '.'
})
Tr.addTranslations('fi-FI', {
  'Number.decimalSeparator' : ','
})



Desk.ElementUtils = {
  getComputedStyle : function(elem) {
    return document.defaultView.getComputedStyle(elem, '')
  },

  insertAfter : function(elem, obj, ref) {
    return elem.insertBefore(obj, ref.nextSibling)
  },

  insertChild : function(elem, obj) {
    if (elem.firstChild)
      return elem.insertBefore(obj, elem.firstChild)
    else
      return elem.appendChild(elem, obj)
  },

  append : function(elem) {
    var objs = $A(arguments).slice(1)
    for (var i=0; i<objs.length; i++) {
      var obj = objs[i]
      if (typeof obj == 'string' || typeof obj == 'number') {
        elem.appendChild(T(obj.toString()))
      } else {
        elem.appendChild(obj)
      }
    }
    return elem
  },

  detachSelf : function(elem, obj) {
    if (elem.parentNode)
      return elem.parentNode.removeChild(elem)
  },

  replaceWithEditor : function(elem, callback) {
    Element.replaceWithEditor(elem, callback)
  },

  byTag : function(elem, tag) {
    return elem.getElementsByTagName(tag)
  },

  $ : function(elem, id){
    if (elem == document || elem == window) {
      return document.getElementById(id)
    } else {
      if (!elem.childNodes) return false
      var gc
      var cn
      // check this level, then do depth-first search
      for(var j=0;j < elem.childNodes.length;j++) {
        cn = elem.childNodes[j]
        if (cn.id == id) return cn
      }
      for(var j=0;j<elem.childNodes.length;j++) {
        cn = $(elem.childNodes[j])
        if (cn.$) {
          gc = cn.$(id)
          if (gc) return gc
        }
      }
      return false
    }
  }
}

Element.addMethods(Desk.ElementUtils)
Tr.addTranslations('en-US', {
  'Element.edit_failed' : function(reason) {
    return 'edit failed: ' + reason
  }
})
Element.makeEditable = function(elem, path, key, validator, title) {
  elem.className = elem.className + " editable"
  elem.title = (title || "Click to edit")
  elem.addEventListener("click", function(e){
    Element.replaceWithEditor(elem, function(new_value) {
      var sendval = new_value
      if (validator)
        sendval = validator(sendval)
      if (sendval && new_value != elem.oldValue) {
        var oldval = elem.textContent
        var old_color = elem.style.color
        elem.innerHTML = new_value
        elem.style.color = 'red'
        var params = {}
        params[key] = sendval
        new Ajax.Request(path, {
          parameters : params,
          onSuccess: function(res) {
            elem.style.color = old_color
          },
          onFailure: function(res) {
            elem.innerHTML = oldval + " (" + Tr("Element.edit_failed", res.statusText)+")"
            elem.style.color = old_color
          }
        })
      }
    })
  }, false)
}
Element.replaceWithEditor = function(elem, callback, oncancel) {
  var input = E('input', null, null, null, null, {type:"text", value:" "})
  var cs = $(elem).getComputedStyle()
  Object.forceExtend(input.style, cs)
  input.style.minWidth = elem.offsetWidth + 'px'
  input.addEventListener("keypress", function(e){
    if ((e.charCode || e.keyCode) == 27) this.cancel()
  }, false)
  input.cancel = function(){
    this.parentNode.insertBefore(elem, this)
    $(this).detachSelf()
    if (oncancel) oncancel()
  }
  var sf = function(ev){
    if (this.iv) clearTimeout(this.iv)
    if (!this.parentNode) return // already detached
    callback(this.value)
    this.cancel()
  }
  $(elem.parentNode).insertAfter(input, elem)
  $(elem).detachSelf()
  elem.oldValue = elem.textContent
  input.value = elem.textContent + " :) "
  input.value = elem.textContent
  input.addEventListener("blur", sf, false)
  input.addEventListener("change", sf, false)
  input.focus()
}



function Empty() {
  var obj = {}
  for (i in obj) delete obj[i]
  return obj
}


EventListener = {
  newEvent : function(type, e) {
    if (!this.listeners) return
    var l = this.listeners[type]
    if (l) {
      e.type = type
      e.target = this
      for (var i=0; i<l.length; i++) l[i](e)
    }
  },

  addListener : function(type, handler) {
    if (!this.listeners) this.listeners = Empty()
    if (!this.listeners[type]) this.listeners[type] = []
    this.listeners[type].push(handler)
  },

  removeListener : function(type, handler) {
    if (!this.listeners || !this.listeners[type]) return
    this.listeners[type].deleteFirst(handler)
    if (this.listeners[type].isEmpty())
      delete this.listeners[type]
  }
}



Desk.Draggable = {
  currentlyDragged : null,
  dragEnded : false,
  
  makeDraggable : function(elem) {
    Object.extend(elem, Desk.Draggable.Mixin)
    elem.addEventListener('mousedown', elem.startDrag.bind(elem), true)
  },

  drag: function(e) {
    if (this.beingDragged) {
      var pv = new Vector(Event.pointerX(e), Event.pointerY(e))
      this.dragElement.x = pv.x
      this.dragElement.y = pv.y 
      this.dragElement.style.left = this.dragElement.x + 'px'
      this.dragElement.style.top = this.dragElement.y + 'px'
      this.dragCur = pv
      Event.stop(e)
    } else if (this.dragEnded) {
      this.dragEnded = false
      Desk.Droppable.cancelDrop()
    } else {
      if (this.currentlyDragged) {
        var pv = new Vector(Event.pointerX(e), Event.pointerY(e))
        if (pv.distance(this.dragStart) > 2) {
          this.beingDragged = true
          this.dragEnded = false
          this.dragElement = this.currentlyDragged.cloneNode(true)
          Object.forceExtend(this.dragElement, {
            x:pv.x, y:pv.y
          })
          this.dragElement.className += ' dragged'
          Object.forceExtend(this.dragElement.style, {
            display: 'block',
            position: 'fixed',
            zIndex: 1000,
            marginLeft: (-this.currentlyDragged.offsetWidth / 2) + 'px',
            marginTop: (-this.currentlyDragged.offsetHeight / 2) + 'px',
            left: this.dragElement.x + 'px',
            top: this.dragElement.y + 'px',
            width: this.currentlyDragged.getWidth() + 'px',
            height: this.currentlyDragged.getHeight() + 'px'
          })
          document.body.appendChild(this.dragElement)
          this.dragCur = pv
        }
        Event.stop(e)
      }
    }
  },
  
  endDrag: function(e) {
    if (this.currentlyDragged) {
      if (this.beingDragged) {
        this.beingDragged = false
        this.dragElement.parentNode.removeChild(this.dragElement)
        this.dragElement = null
        Desk.Droppable.drop(this.currentlyDragged)
        this.dragEnded = true
      }
      this.currentlyDragged = null
      Event.stop(e)
    }
  }
}
Desk.Draggable.Mixin = {
  startDrag: function(e) {
    if (Event.isLeftClick(e)) {
      Desk.Draggable.currentlyDragged = this
      Desk.Draggable.dragStart = new Vector(Event.pointerX(e), Event.pointerY(e))
      Event.stop(e)
    }
  }
}
window.addEventListener('mousemove', Desk.Draggable.drag.bind(Desk.Draggable), false)
window.addEventListener('mouseup', Desk.Draggable.endDrag.bind(Desk.Draggable), false)


Desk.Droppable = {
  dropTarget : null,

  drop : function(dragged) {
    this.dropped = dragged
  },

  cancelDrop : function() {
    this.dropped = null
  },

  makeDroppable : function(elem) {
    elem.addEventListener('mousemove', function(e){
      if (Desk && Desk.Droppable && Desk.Droppable.dropped) {
        this.drop(Desk.Droppable.dropped, e)
        Desk.Droppable.cancelDrop()
      }
    }, true)
  }
}
Desk.Droppable.Mixin = {
  drop : function(dragged, e) {
  }
}


Vector = function(x,y) {
  this.x = x
  this.y = y
  this.length = Math.sqrt(x*x+y*y)
}
Vector.prototype = {
  add : function(v){
    return new Vector(this.x + v.x, this.y + v.y)
  },
  
  sub : function(v){
    return new Vector(this.x - v.x, this.y - v.y)
  },

  reverse : function(){
    return new Vector(-this.x, -this.y)
  },
  
  distance : function(v) {
    return this.sub(v).length
  },
  
  dot : function(v) {
    return (this.x*v.x + this.y*v.y)
  },
  
  multiply : function(s) {
    return new Vector(this.x * s, this.y * s)
  }
}


Plane = function(x,y,d) {
  Vector.apply(this, [x, y])
  this.d = d
}
Plane.prototype = Object.extend(Object.extend({}, Vector.prototype), {
  distance : function(p) {
    return Math.abs((this.dot(p)-this.d) / this.length)
  }
})


Desk.Menu = function() {
  this.element = E('ul', null, null, 'Menu')
  this.element.addEventListener('contextmenu', function(ev) {
    if (!Event.isLeftClick(ev) && !(ev.ctrlKey))
      Event.stop(ev)
  }.bind(this), false)
  this.element.addEventListener('mouseup', function(e){
    this.skipHide = true
  }.bind(this), true)
  this.hideHandler = (function(){ this.hide(true) }).bind(this)
}
Desk.Menu.prototype = {
  emptyIcon : 'transparent.gif',
  checkedIcon : 'icons/checked.png',
  uncheckedIcon : 'icons/unchecked.png',

  bind : function(element) {
    element.addEventListener('contextmenu', function(ev) {
      if (!ev.useDefaultAction && !Event.isLeftClick(ev) && !ev.ctrlKey) {
        this.show(ev)
        this.skipHide = true
        Event.stop(ev)
      }
    }.bind(this), false)
  },

  stop : function(element) {
    element.addEventListener('contextmenu', function(ev) {
      if (!Event.isLeftClick(ev) && !ev.ctrlKey ) {
        ev.useDefaultAction = true
      }
    }.bind(this), false)
  },
  
  addItem : function(name, callback, icon) {
    if (!icon) icon = this.emptyIcon
    var li = E('li', null, null, 'MenuItem')
    var iconImg = E('img')
    var ei = this.emptyIcon
    iconImg.onload = function() {
      if (iconImg.src != ei) {
        delete iconImg.onload 
        //iconImg.style.width = (iconImg.width / 6) + 'ex'
        iconImg.style.height = (iconImg.height / 6) + 'ex'
      }
    }
    iconImg.src = icon
    li.appendChild(iconImg)
    li.appendChild(T(name))
    li.enabled = true
    li.checked = null
    if (callback) {
      var t = this
      li.addEventListener('mouseup', function(e){
        if (this.enabled) t.hide()
        if (this.enabled) return callback(e)
      }, false)
      li.addEventListener('mousedown', function(e) {
        Event.stop(e)
      }, false)
    }
    li.enable = function(){
      li.enabled = true
      li.className = li.className.replace(/\sdisabled\b|$/, '')
    }
    li.disable = function(){
      li.enabled = false
      li.className = li.className.replace(/\sdisabled\b|$/, ' disabled')
    }
    li.check = function(){
      li.checked = true
      iconImg.src = this.checkedIcon
      li.className = li.className.replace(/\s(un)?checked\b|$/, ' checked')
    }.bind(this)
    li.uncheck = function(){
      li.checked = false
      iconImg.src = this.uncheckedIcon
      li.className = li.className.replace(/\s(un)?checked\b|$/, ' unchecked')
    }.bind(this)
    this.element.appendChild(li)
  },
  
  addTitle : function(title) {
    var li = E('li', null, null, 'MenuTitle')
    var h4 = E('h4', title)
    li.appendChild(h4)
    li.enable = li.disable = li.check = li.uncheck = function(){}
    this.element.appendChild(li)
  },
  
  addSeparator : function() {
    var li = E('li', null, null, 'MenuSeparator')
    li.enable = li.disable = li.check = li.uncheck = function(){}
    this.element.appendChild(li)
  },
  
  addSubMenu : function(title, submenuCreator) {
    var li = E('li', null, null, 'MenuItem SubMenu')
    var iconImg = E('img')
    iconImg.src = this.emptyIcon
    li.appendChild(iconImg)
    li.appendChild(T(title))
    li.submenuCreator = submenuCreator
    li.addEventListener('mouseup', function(e){
      if (this.subMenu && this.subMenu.isVisible()) {
        this.subMenu.hide()
        this.subMenu = null
      } else {
        this.subMenu = new Desk.Menu()
        this.submenuCreator(this.subMenu)
        this.subMenu.show(Event.pointerX(e), Event.pointerY(e))
      }
      Event.stop(e)
    }.bind(li), false)
    this.element.appendChild(li)
  },
  
  show : function(x,y) {
    if (this.element.parentNode) this.hide()
    if (typeof x == 'object') {
      y = Event.pointerY(x)
      x = Event.pointerX(x)
    }
    Object.forceExtend(this.element.style, {
      position: 'fixed',
      left: 0 + 'px',
      top: 0 + 'px',
      visibility: 'hidden'
    })
    document.body.appendChild(this.element)
    if (x + this.element.offsetWidth >  window.innerWidth)
      x -= this.element.offsetWidth
    if (y + this.element.offsetHeight >  window.innerHeight)
      y -= this.element.offsetHeight
    this.element.style.left = x + 'px'
    this.element.style.top = y + 'px'
    window.addEventListener('mouseup', this.hideHandler, false)
    this.element.style.visibility = null
  },
  
  hide : function(skippable) {
    if (skippable && this.skipHide) {
      this.skipHide = false
    } else {
      if (this.element.parentNode)
        this.element.parentNode.removeChild(this.element)
      window.removeEventListener('mouseup', this.hideHandler, false)
    }
  },
  
  isVisible : function() {
    return this.element.parentNode != undefined
  },
  
  findItems : function(name) {
    return this.element.childNodes.findAll(function(c){
      return c.lastChild && c.lastChild.data == name
    })
  },
  
  enableItem : function(name) {
    this.findItems(name).invoke('enable')
  },
  
  disableItem : function(name) {
    this.findItems(name).invoke('disable')
  },
  
  checkItem : function(name) {
    this.findItems(name).invoke('check')
  },
  
  uncheckItem : function(name) {
    this.findItems(name).invoke('uncheck')
  }
}

NodeList.prototype._each = function(f){
  for (var i=0; i<this.length; i++)
    f(this[i])
  return this
}
Object.extend(NodeList.prototype, Enumerable)
