// Copies all of obj's properties to this.
Object.forceExtend = function(dest,src){
  for(var i in src)
    try{ dest[i] = src[i] } catch(e) {}
  return dest
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




Draggable = {
  currentlyDragged : null,
  dragEnded : false,
  
  makeDraggable : function(elem) {
    Object.extend(elem, Draggable.Mixin)
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
      Droppable.cancelDrop()
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
            marginLeft: (this.currentlyDragged.offsetLeft - this.dragStart.x) + 'px',
            marginTop: (this.currentlyDragged.offsetTop - this.dragStart.y) + 'px',
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
        Droppable.drop(this.currentlyDragged)
        this.dragEnded = true
      }
      this.currentlyDragged = null
    }
  }
}
Draggable.Mixin = {
  startDrag: function(e) {
    if (Event.isLeftClick(e)) {
      Draggable.currentlyDragged = this
      Draggable.dragStart = new Vector(Event.pointerX(e), Event.pointerY(e))
    }
  }
}
window.addEventListener('mousemove', Draggable.drag.bind(Draggable), false)
window.addEventListener('mouseup', Draggable.endDrag.bind(Draggable), false)


Droppable = {
  dropTarget : null,

  drop : function(dragged) {
    this.dropped = dragged
  },

  cancelDrop : function() {
    this.dropped = null
  },

  makeDroppable : function(elem) {
    elem.addEventListener('mousemove', function(e){
      if (Droppable.dropped) {
        this.drop(Droppable.dropped, e)
        Droppable.cancelDrop()
      }
    }, true)
  }
}
Droppable.Mixin = {
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
  this.element.addEventListener('mouseup', function(e){
    this.skipHide = true
  }.bind(this), true)
  this.hideHandler = this.hide.bind(this)
}
Desk.Menu.prototype = {
  emptyIcon : 'transparent.gif',
  checkedIcon : 'icons/checked.png',
  uncheckedIcon : 'icons/unchecked.png',
  
  addItem : function(name, callback, icon) {
    if (!icon) icon = this.emptyIcon
    var li = E('li', null, null, 'MenuItem')
    var iconImg = E('img')
    iconImg.src = icon
    li.appendChild(iconImg)
    li.appendChild(T(name))
    li.enabled = true
    li.checked = false
    if (callback)
      li.addEventListener('click', function(e){
        if (this.enabled) return callback(e)
      }, false)
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
    li.addEventListener('click', function(e){
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
  
  hide : function() {
    if (this.skipHide) {
      this.skipHide = false
    } else {
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