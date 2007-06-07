Tr.addTranslations('en-US', {
  'Window' : 'Window',
  'Window.Shaded' : 'Shaded',
  'Window.Minimized' : 'Minimized',
  'Window.Maximized' : 'Maximized',
  'Window.Close' : 'Close',
  'Window.Duplicate' : 'Duplicate',
  'Button.Duplicate' : 'Duplicate',
  'Button.Close' : 'Close',
  'Button.Minimize' : 'Minimize',
  'Button.Maximize' : 'Maximize',
  'WindowGroup.default' : 'default'
})
Tr.addTranslations('fi-FI', {
  'Window' : 'Ikkuna',
  'Window.Shaded' : 'Kutistettu',
  'Window.Minimized' : 'Pienennetty',
  'Window.Maximized' : 'Suurennettu',
  'Window.Close' : 'Sulje',
  'Window.Duplicate' : 'Monista',
  'Button.Duplicate' : 'Monista',
  'Button.Close' : 'Sulje',
  'Button.Minimize' : 'Pienennä',
  'Button.Maximize' : 'Suurenna',
  'WindowGroup.default' : 'oletus'
})


Desk.Window = function(content, config){
  if (config) Object.extend(this, config)
  if (!this.buttons)
    this.buttons = this.defaultButtons.map()
  this.init()
  if (typeof content == 'string')
    this.setSrc(content)
  else
    this.setContent(content)
  if (config) {
    if (config.title) this.setTitle(config.title)
    if (config.minimized) this.setMinimized(config.minimized)
  }
  this.setGroup(config && config.group)
  this.setWindowManager((this.windowManager || Desk.Windows))
  if (this.shaded) {
    this.shaded = false
    this.setShaded(true)
  }
  if (this.maximized) {
    this.maximized = false
    this.setMaximized(true)
  }
  this.focus()
}
Desk.Window.loadSession = function(data){
  return new Desk.Window(data.content, data.config)
}
Desk.Window.prototype = {
  shaded : false,
  maximized : false,
  focused : false,
  minimized : false,
  groupCollapsed : false,
  x : 0, y : 0, z : 0,
  layer : 0,
  clickRadius : 3,
  movable : true,
  resizable : true,
  defaultButtons : ['Minimize', 'Maximize', 'Close'],
  group : 'default',
  showInTaskbar : true,
  avoid: false,
  easyMove: false,
  src: null,
  metadata: null,
  loader : 'Desk.Window',

  init : function() {
    this.initElements()
    this.initEventListeners()
    this.initButtons()
  },

  // toggles window maximize
  maximize : function() {
    this.setMaximized(!this.maximized)
  },

  // toggles window shading (whether it's just a titlebar or not)
  shade : function() {
    this.setShaded(!this.shaded)
  },

  close : function() {
    this.setWindowManager(null)
  },

  minimize : function() {
    this.setMinimized(!this.minimized)
  },

  groupCollapse : function() {
    this.setGroupCollapsed(!this.groupCollapsed)
  },

  bringToFront : function() {
    this.windowManager.bringToFront(this)
  },

  sendToBack : function() {
    this.windowManager.sendToBack(this)
  },

  focus : function() {
    this.windowManager.focus(this)
  },

  duplicate : function() {
    var dup = new Desk.Window(
      this.dupEl(this.content),
      {
        buttons : this.buttons,
        x : this.x + 10,
        y : this.y + 10,
        title : this.dupEl(this.title),
        layer : this.layer,
        movable : this.movable,
        showInTaskbar : this.showInTaskbar,
        avoid : this.avoid,
        src : this.src,
        metadata : this.metadata,
        group : this.group,
        minimized : this.minimized,
        shaded : this.shaded,
        maximized: this.maximized
      }
    )
    return dup
  },

  dumpSession : function() {
    var dump = {
      content : this.src,
      config : {
        buttons : this.buttons,
        x : this.x,
        y : this.y,
        title : this.titleElement.innerHTML,
        layer : this.layer,
        movable : this.movable,
        showInTaskbar : this.showInTaskbar,
        avoid : this.avoid,
        group : this.group,
        minimized : this.minimized,
        shaded : this.shaded,
        maximized: this.maximized
      }
    }
    return {
      loader : this.loader,
      data : dump
    }
  },

  dupEl : function(obj) {
    if (typeof obj == 'string')
      return obj.toString()
    else
      return obj.cloneNode(true)
  },

  // Create elements for the actual window and the titlebars.
  initElements : function(){
    this.borders = E('div', null, null, 'windowBorder')
    this.element = E('div', null, null, 'window',
      {position: 'absolute', left:this.x+'px', top:this.y+'px'})
    this.backgroundElement = E('div', null, null, 'windowBackground',
      {position: 'absolute', zIndex: -1,
       left: '0px', top: '0px',
       width: '100%', height: '100%'})
    this.titlebarElement = E('div', null, null, 'windowTitlebar')
    this.contentElement = E('div', null, null, 'windowContent')
    this.titleElement = E('h3', this.title, null, 'windowTitle')
    this.buttonsElement = E('div', null, null, 'windowButtons')
    this.titlebarElement.appendChild(this.titleElement)
    this.titlebarElement.appendChild(this.buttonsElement)
    this.element.appendChild(this.backgroundElement)
    this.element.appendChild(this.borders)
    this.borders.appendChild(this.titlebarElement)
    this.borders.appendChild(this.contentElement)
    this.taskbarElement = E('div', null, null, 'windowTaskbarEntry')
    this.taskbarTitleElement = E('h4', null, null, 'windowTaskbarTitle')
    this.taskbarElement.appendChild(this.taskbarTitleElement)
  },

  initEventListeners : function() {
    // click to front
    this.element.addEventListener('click', function(e){
      if (!this.dragStart ||
          this.dragEnd.distance(this.dragStart) < this.clickRadius) {
        if (Event.isLeftClick(e)) {
          if (!e.shiftKey) {
            this.focus()
            this.bringToFront()
          } else {
            this.sendToBack()
          }
        }
      }
    }.bind(this), false)

    // dragging the window
    this.element.addEventListener('mousedown', this.focus.bind(this), false)
    this.element.addEventListener('mousedown', this.startMove.bind(this), false)
    this.endMoveHandler = this.endMove.bind(this)
    this.mouseMoveHandler = this.mouseMove.bind(this)
    this.addGlobalListeners()
    
    var mincol = function(){
      if (this.minimized || this.groupCollapsed) {
        this.removeGlobalListeners()
      } else {
        this.addGlobalListeners()
      }
    }.bind(this)
    this.addListener('close', this.removeGlobalListeners.bind(this))
    this.addListener('minimizeChange', mincol)
    this.addListener('groupCollapseChange', mincol)

    // double-click titlebar to toggle windowshade
    this.titlebarElement.addEventListener('dblclick', function(e){
      this.shade()
    }.bind(this), false)

    Desk.Draggable.makeDraggable(this.taskbarElement)
    this.taskbarElement.window = this
    this.taskbarTitleElement.addEventListener('mousedown', function(e){
      if (Event.isLeftClick(e)) {
        this.focus()
        this.bringToFront()
        Event.stop(e)
      }
    }.bind(this), false)
    this.taskbarTitleElement.addEventListener('click', function(e){
      if (Event.isLeftClick(e)) {
        this.focus()
        this.bringToFront()
        this.minimize()
        Event.stop(e)
      }
    }.bind(this), false)

    var bsz = 3

    this.borders.addEventListener('mousemove', function(e){
      if (e.target == this) {
        var prefix = ''
        var left = e.layerX <= bsz
        var right = e.layerX >= (this.offsetWidth - bsz)
        var top = e.layerY <= bsz
        var bottom = e.layerY >= (this.offsetHeight - bsz)
        if (top) prefix += 'N'
        if (bottom) prefix += 'S'
        if (left) prefix += 'W'
        if (right) prefix += 'E'
        if (prefix.length >= 0) {
          this.style.cursor = prefix + '-resize'
        } else {
          this.style.cursor = 'default'
        }
      } else {
        this.style.cursor = 'default'
      }
    }, false)

    var makeCheckButton = function(item, name) {
      this.addListener(name.toLowerCase().slice(0,-1) + 'Change', function(e){
        this.menu[(e.value ? '' : 'un') + 'checkItem'](item)
      }.bind(this))
      if (this[name.toLowerCase()])
        this.menu.checkItem(item)
      else
        this.menu.uncheckItem(item)
    }.bind(this)
    this.menu = new Desk.Menu()
    this.menu.addTitle(Tr('Window'))
    this.menu.addItem(Tr('Window.Shaded'), this.shade.bind(this))
    this.menu.addItem(Tr('Window.Minimized'), this.minimize.bind(this))
    this.menu.addItem(Tr('Window.Maximized'), this.maximize.bind(this))
    makeCheckButton(Tr('Window.Shaded'), 'Shaded')
    makeCheckButton(Tr('Window.Minimized'), 'Minimized')
    makeCheckButton(Tr('Window.Maximized'), 'Maximized')
/*    this.menu.addSeparator()
    this.menu.addItem(Tr('Window.Duplicate'), this.duplicate.bind(this), 'icons/Duplicate.png')*/
    this.menu.addSeparator()
    this.menu.addItem(Tr('Window.Close'), this.close.bind(this), 'icons/Close.png')
    this.menu.bind(this.taskbarTitleElement)
    this.menu.bind(this.titlebarElement)
    this.menu.stop(this.element)
  },

  initButtons : function() {
    for (var i=0; i<this.buttons.length; i++) {
      var bn = this.buttons[i]
      var b = new Desk.Button(bn, this[bn.toLowerCase()].bind(this))
      this.buttonsElement.appendChild(b)
      this.buttons[bn.toLowerCase()] = b
    }
  },

  addGlobalListeners : function(){
    if (!this.globalListenersOn) {
      this.globalListenersOn = true
      window.addEventListener('mouseup', this.endMoveHandler, false)
      window.addEventListener('mousemove', this.mouseMoveHandler, false)
    }
  },
  
  removeGlobalListeners : function(){
    if (this.globalListenersOn) {
      this.globalListenersOn = false
      window.removeEventListener('mouseup', this.endMoveHandler, false)
      window.removeEventListener('mousemove', this.mouseMoveHandler, false)
    }
  },

  startMove : function(e){
    if (this.resizable && this.validMoveTarget(e) && Event.isLeftClick(e) &&
        Math.abs(e.layerX - this.element.offsetWidth) < 30 &&
        Math.abs(e.layerY - this.element.offsetHeight) < 30
    ) {
      this.resizeStart = new Vector(Event.pointerX(e), Event.pointerY(e))
      this.originalSize = new Vector(
        this.element.offsetWidth, this.element.offsetHeight)
      this.originalPosition = new Vector(this.x, this.y)
      this.resizing = true
      Event.stop(e)
      this.newEvent('dragStart', { value: [this.x, this.y] })
    } else if (this.validMoveTarget(e) && Event.isLeftClick(e)) {
      this.dragStart = new Vector(Event.pointerX(e), Event.pointerY(e))
      this.dragCur = this.dragStart
      this.dragging = true
      if (!e.shiftKey) {
        this.focus()
        this.bringToFront()
      } else {
        this.sendToBack()
      }
      Event.stop(e)
      this.newEvent('dragStart', { value: [this.x, this.y] })
    }
  },

  validMoveTarget : function(e){
    if (this.easyMove)
      return true
    var validTargets = [
      this.element, this.backgroundElement,
      this.borders, this.titlebarElement,
      this.titleElement, this.buttonsElement
    ]
    return validTargets.include(e.target)
  },

  mouseMove : function(e){
    if (this.resizing && this.resizeStart) {
      var p = new Vector(Event.pointerX(e), Event.pointerY(e))
      var d = p.sub(this.resizeStart)
      var wantedSize = this.originalSize.add(d)
      var dx = Math.max(-wantedSize.x, 0)
      var dy = Math.max(-wantedSize.y, 0)
      this.setX(this.originalPosition.x - dx)
      this.setY(this.originalPosition.y - dy)
      this.setSize(Math.abs(wantedSize.x), Math.abs(wantedSize.y))
      this.dragCur = p
      Event.stop(e)
    } else if (this.dragging) {
      var p = new Vector(Event.pointerX(e), Event.pointerY(e))
      if (this.movable && this.dragCur) {
        var d = p.sub(this.dragCur)
        this.setX(this.x + d.x)
        this.setY(this.y + d.y)
      }
      this.dragCur = p
      Event.stop(e)
    }
  },

  setSize : function(w, h) {
    this.element.style.width = (typeof w == 'string' ? w : w + 'px')
    this.element.style.height = (typeof h == 'string' ? h : h + 'px')
    this.contentElement.style.height = (
      this.element.offsetHeight -
      this.contentElement.offsetTop - 6) + 'px'
    this.contentElement.style.width = (
      this.element.offsetWidth - 8) + 'px'
    this.newEvent('resize', { value : [w,h] })
    this.setX(this.x)
    this.setY(this.y)
  },

  endMove : function(e){
    this.dragEnd = new Vector(Event.pointerX(e), Event.pointerY(e))
    this.dragging = false
    this.resizing = false
    this.newEvent('dragEnd', { value: [this.x, this.y] })
  },

  setTitle : function(new_value) {
    var ov = this.title
    this.setElementContent(this.titleElement, new_value)
    this.setElementContent(this.taskbarTitleElement, new_value, true)
    this.title = new_value
    this.newEvent('titleChange', {old_value: ov, value: new_value})
  },

  setGroup : function(new_value) {
    if (!new_value) new_value = 'default'
    var ov = this.group
    if (!ov) ov = 'default'
    var gre = new RegExp('\\b'+ov+'\\b')
    if (this.element.className.match(gre))
      this.element.className = this.element.className.replace(gre, new_value)
    else
      this.element.className += ' ' + new_value
    this.group = new_value
    this.newEvent('groupChange', {old_value: ov, value: new_value})
  },

  setContainer : function(new_value) {
    var ov = this.container
    if (this.container && this.container.removeChild)
      this.container.removeChild(this.element)
    if (new_value && new_value.appendChild)
      new_value.appendChild(this.element)
    this.container = new_value
    this.newEvent('containerChange', {old_value: ov, value: new_value})
    this.setX(this.x)
    this.setY(this.y)
  },

  setWindowManager : function(new_value) {
    var ov = this.windowManager
    if (this.windowManager) this.windowManager.removeWindow(this)
    if (new_value) new_value.addWindow(this)
    this.windowManager = new_value
    this.newEvent('windowManagerChange', {old_value: ov, value: new_value})
  },

  setContent : function(new_value) {
    var ov = this.content
    this.setElementContent(this.contentElement, new_value)
    this.content = new_value
    this.newEvent('contentChange', {old_value: ov, value: new_value})
  },

  setElementContent : function(element, new_value, clone) {
    element.innerHTML = ''
    if (new_value) {
      if (typeof new_value == 'string') { // small magic
        element.innerHTML = new_value
      } else {
        if (clone) {
          element.appendChild(T(new_value.textContent))
        } else {
          element.appendChild(new_value)
        }
      }
    }
  },
  
  setMaximized : function(new_value) {
    var ov = this.maximized
    if (new_value != this.maximized) {
      this.maximized = new_value
      if (this.shaded) this.shade()
      if (this.buttons.maximize) this.buttons.maximize.toggle()
      this.bringToFront()
      this.maximizeHandler(new_value)
    }
    this.newEvent('maximizeChange', {old_value: ov, value: new_value})
  },

  maximizeHandler : function(new_value) {
    if (new_value) {
      this.movable = false
      this.oldCoords = {x:this.x, y:this.y,
        w:this.element.offsetWidth,
        h:this.element.offsetHeight}
      this.setX(0)
      this.setY(0)
      this.setSize(this.container.offsetWidth, this.container.offsetHeight)
    } else {
      this.movable = true
      this.setX(this.oldCoords.x)
      this.setY(this.oldCoords.y)
      this.setSize(this.oldCoords.w, this.oldCoords.h)
    }
  },

  setShaded : function(new_value) {
    var ov = this.shaded
    this.shaded = new_value
    if (new_value) {
      this.titlebarElement.style.minWidth =
        this.contentElement.offsetWidth + 'px'
      this.contentElement.style.display = 'none'
      this.previousHeight = this.element.style.height
      this.element.style.height = null
    } else {
      this.contentElement.style.display = null
      this.titlebarElement.style.minWidth = null
      this.element.style.height = this.previousHeight
    }
    this.newEvent('shadeChange', {old_value: ov, value: new_value})
  },

  setFocus : function(new_value) {
    this.focused = new_value
    this.element.className = this.element.className.replace(
      /\s(focused|blurred)\b|$/, (new_value ? ' focused' : ' blurred'))
    this.taskbarElement.className = this.taskbarElement.className.replace(
      /\s(focused|blurred)\b|$/, (new_value ? ' focused' : ' blurred'))
    this.newEvent('focusChange', {value: new_value})
  },

  setMinimized : function(new_value) {
    var ov = this.minimized
    this.minimized = new_value
    this.element.style.display = (this.minimized || this.groupCollapsed ?
      'none' : 'block'
    )
    this.newEvent('minimizeChange', {old_value: ov, value: new_value})
  },

  setGroupCollapsed : function(new_value) {
    var ov = this.groupCollapsed
    this.groupCollapsed = new_value
    this.element.style.display = (this.minimized || this.groupCollapsed ?
      'none' : 'block'
    )
    this.newEvent('groupCollapseChange', {old_value: ov, value: new_value})
  },

  setX : function(new_value) {
    if (!this.avoid) {
      if (new_value < -this.element.offsetWidth + 50) {
        new_value = -this.element.offsetWidth + 50
      } else if (this.container && new_value > this.container.offsetWidth - 50) {
        new_value = this.container.offsetWidth - 50
      }
    }
    this.element.style.left = new_value + 'px'
    this.x = new_value
    this.newEvent('positionChange', {x: this.x, y: this.y})
  },

  setY : function(new_value) {
    if (!this.avoid) {
      if (this.easyMove && new_value < -this.element.offsetHeight + 50) {
        new_value = -this.element.offsetHeight + 50
      } else if (!this.easyMove && new_value < 0) {
        new_value = 0
      } else if (this.container && new_value > this.container.offsetHeight - 50) {
        new_value = this.container.offsetHeight - 50
      }
    }
    this.element.style.top = new_value + 'px'
    this.y = new_value
    this.newEvent('positionChange', {x: this.x, y: this.y})
  },

  setZ : function(new_value) {
    var ov = this.z
    this.element.style.zIndex = new_value
    this.z = new_value
    this.newEvent('zChange', {old_value: ov, value: new_value})
  },

  setSrc : function(new_src) {
    this.metadata = Metadata.get(new_src)
    this.src = new_src
    if (this.metadata.title && this.metadata.title.length > 0)
      this.setTitle(this.metadata.title)
    this.easyMove = this.metadata.easyMove
    if (this.metadata.init) this.metadata.init(new_src, this)
    if (new_src == document.location.href)
      this.setContent(A(new_src, new_src))
    else
      this.setContent(this.metadata.makeEmbed(new_src))
  }
}
Object.extend(Desk.Window.prototype, EventListener)







