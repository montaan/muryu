Desk.WindowManager = function(container){
  this.windows = []
  this.windowContainer = E('div', null, null, 'windowContainer')
  this.containerStyleChanged = this.containerStyleChangeHandler.bind(this)
  this.containerMonitor = setInterval(this.containerStyleChanged, 100)
  this.setContainer(container)
}
Desk.WindowManager.prototype = {
  setContainer : function(new_value) {
    if (this.container && this.container.removeChild) {
      this.container.removeChild(this.windowContainer)
    }
    this.container = new_value
    if (new_value && new_value.appendChild) {
      new_value.appendChild(this.windowContainer)
    }
  },

  containerStyleChangeHandler : function() {
    if (this.container && 
        (this.container.style.width != this.previousWidth ||
         this.container.style.height != this.previousHeight)) {
      this.updateConstraints()
      this.previousWidth = this.container.style.width
      this.previousHeight = this.container.style.height
      this.windows.each(function(win) {
        if (win.maximized) {
          win.setSize(win.container.offsetWidth,win.container.offsetHeight)
        }
      })
    }
  },

  addWindow : function(win) {
    if (!this.windows.include(win)) this.pushWindow(win)
    win.setContainer(this.windowContainer)
    this.update()
    if (!win.transient)
      Session.add(win)
    this.newEvent('add', {window: win})
  },

  removeWindow : function(win) {
    if (!this.windows.deleteFirst(win)) return
    win.setContainer(null)
    Session.remove(win)
    this.newEvent('remove', {window: win})
  },

  bringToFront : function(win) {
    if (!this.windows.deleteFirst(win)) return
    this.pushWindow(win)
    this.update()
  },

  sendToBack : function(win) {
    if (!this.windows.deleteFirst(win)) return
    this.unshiftWindow(win)
    this.update()
  },

  focus : function(win) {
    this.windows.each(function(w){
      if (w != win) w.setFocus(false)
    })
    win.setFocus(true)
  },

  update : function() {
    for (var i = 0; i < this.windows.length; i++)
      this.windows[i].setZ(i)
  },

  // Push window to the top of its layer.
  // In other words, insert window before
  // the first window that has a greater layer.
  pushWindow : function(win) {
    for (var i=0; i<this.windows.length; i++) {
      var w = this.windows[i]
      if (w.layer > win.layer) {
        this.windows.splice(i, 0, win)
        return
      }
    }
    this.windows.push(win)
  },

  // Unshift window to the bottom of its layer.
  // In other words, insert window before the
  // the first window that has an equal or
  // greater layer.
  unshiftWindow : function(win) {
    for (var i=0; i<this.windows.length; i++) {
      var w = this.windows[i]
      if (w.layer >= win.layer) {
        this.windows.splice(i, 0, win)
        return
      }
    }
    this.windows.push(win)
  },

  updateConstraints : function() {
    if (!this.container) return
    var avoids = this.windows.findAll(function(w){return w.avoid})
    var t = this
    this.left = 0
    this.right = this.fullWidth = parseInt(this.container.style.width)
    this.top = 0
    this.bottom = this.fullHeight = parseInt(this.container.style.height)
    avoids.each(function(a){
      var f = t[a.side+'Constrain']
      if (f) f.apply(t, [a])
    })
    this.width = this.right - this.left
    this.height = this.bottom - this.top
    this.windowContainer.style.left = this.left + 'px'
    this.windowContainer.style.top = this.top + 'px'
    this.windowContainer.style.width = this.width + 'px'
    this.windowContainer.style.height = this.height + 'px'
    this.leftC = this.absLeft = this.width - this.fullWidth +
      (this.fullWidth - this.right)
    this.rightC = this.fullWidth - this.left
    this.topC = this.absTop = this.height - this.fullHeight +
      (this.fullHeight - this.bottom)
    this.bottomC = this.fullHeight - this.top
    avoids.each(function(a){
      var f = t[a.side+'UpdateCoords']
      if (f) f.apply(t, [a])
    })
    this.newEvent('resize',
      {width: this.windowContainer.offsetWidth,
       height: this.windowContainer.offsetHeight})
  },

  leftConstrain : function(win) {
    var tw = win.element.getWidth()
    this.left += tw
  },
  rightConstrain : function(win) {
    var tw = win.element.getWidth()
    this.right -= tw
  },
  topConstrain : function(win) {
    var th = win.element.getHeight()
    this.top += th
  },
  bottomConstrain : function(win) {
    var th = win.element.getHeight()
    this.bottom -= th
  },

  leftUpdateCoords : function(win) {
    var tw = win.element.getWidth()
    win.setY(this.absTop)
    win.element.style.height = this.container.getHeight() + 'px'
    win.setX(this.leftC)
    this.leftC += tw
  },
  rightUpdateCoords : function(win) {
    var tw = win.element.getWidth()
    win.setY(this.absTop)
    win.element.style.height = this.container.getHeight() + 'px'
    win.setX(this.rightC - tw)
    this.rightC -= tw
  },
  topUpdateCoords : function(win) {
    var th = win.element.getHeight()
    win.setY(this.topC)
    this.topC += th
  },
  bottomUpdateCoords : function(win) {
    var th = win.element.getHeight()
    win.setY(this.bottomC - th)
    this.bottomC -= th
  }
}
Object.extend(Desk.WindowManager.prototype, EventListener)
Desk.Windows = new Desk.WindowManager()

