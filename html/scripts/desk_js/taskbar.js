Tr.addTranslations('en-US', {
  'Applets.Taskbar' : 'Taskbar',
  'Applets.Taskbar.window_group' : 'Window group',
  'Applets.Taskbar.collapsed' : 'Collapsed',
  'Applets.Taskbar.rename' : 'Rename',
  'Applets.Taskbar.duplicate' : 'Duplicate',
  'Applets.Taskbar.close_all' : 'Close all',
  'Applets.Taskbar.collapse_all' : 'Collapse all groups',
  'Applets.Taskbar.expand_all' : 'Expand all groups'
})
Tr.addTranslations('fi-FI', {
  'Applets.Taskbar' : 'Ikkunalista',
  'Applets.Taskbar.window_group' : 'Ikkunaryhmä',
  'Applets.Taskbar.collapsed' : 'Piilotettu',
  'Applets.Taskbar.rename' : 'Uudelleennimeä',
  'Applets.Taskbar.duplicate' : 'Monista',
  'Applets.Taskbar.close_all' : 'Sulje kaikki',
  'Applets.Taskbar.collapse_all' : 'Piilota kaikki ryhmät',
  'Applets.Taskbar.expand_all' : 'Laajenna kaikki ryhmät'
})

Applets.Taskbar = function(wm) {
  var el = Applets.create('Taskbar')
  Object.extend(el, Applets.Taskbar.prototype)
  el.windowGroups = new Hash()
  el.init()
  el.setWindowManager(wm || Desk.Windows)
  return el
}
Applets.Taskbar.prototype = {
  init : function() {
    this.element = this
    this.taskbar = this
    this.titleElement.innerHTML = Tr('Windows')
    this.menu.addItem(
      Tr('Applets.Taskbar.collapse_all'),
      function(){ this.setCollapsedForAll(true) }.bind(this),
      'icons/CollapseAllGroups.png'
    )
    this.menu.addItem(
      Tr('Applets.Taskbar.expand_all'),
      function(){ this.setCollapsedForAll(false) }.bind(this),
      'icons/ExpandAllGroups.png'
    )
    this.menu.addSeparator()
    this.menu.addItem(
      Tr('Applets.Taskbar.close_all'),
      this.closeAll.bind(this),
      'icons/Remove.png'
    )
//     this.formElement = E('form', null, null, 'taskbarForm')
//     this.formTitleElement = E('h5', 'Create window group', null, 'taskbarFormTitle')
//     this.formElement.appendChild(this.formTitleElement)
//     this.textInput = E('input', null, null, 'taskbarTextInput',
//       null, {type:'text'})
//     this.submitInput = E('input', null, null, 'taskbarSubmitInput',
//       null, {type:'submit', value:'+'})
//     this.formElement.appendChild(this.textInput)
//     this.formElement.appendChild(this.submitInput)
//     this.element.appendChild(this.formElement)
//     this.textInput.addEventListener('focus', function(e){
//       this.select()
//     }, false)
//     this.formElement.addEventListener('submit', function(e){
//       var name = this.textInput.value
//       if (name.toString().length > 0) {
//         var unique_name = this.createUniqueGroupName(name)
//         this.createWindowGroup(unique_name)
//       }
//       this.formElement.blur()
//       Event.stop(e)
//     }.bind(this), false)
    this.onWindowAdded = this.onWindowAddHandler.bind(this)
    this.onWindowRemoved = this.onWindowRemoveHandler.bind(this)
    this.onWindowGroupChanged = this.onWindowGroupChangeHandler.bind(this)
    this.createWindowGroup('default')
  },

  setCollapsedForAll : function(new_value) {
    this.windowGroups.each(function(kv, i){
      kv[1].setCollapsed(new_value) // prototype.js ... some days
    })
  },

  closeAll : function() {
    this.windowGroups.each(function(kv, i){
      kv[1].close()
    })
  },

  createUniqueGroupName : function(name) {
    var new_name = name.toString()
    var i = 2
    while (this.windowGroups[new_name]) {
      new_name = name + ' #' + i
      i++
    }
    return new_name
  },

  setWindowManager : function(wm) {
    if (this.windowManager) {
      this.windowManager.removeListener('add', this.onWindowAdded)
      this.windowManager.removeListener('remove', this.onWindowRemoved)
      this.windowManager.taskbar = null
    }
    this.windowManager = wm
    if (this.windowManager) {
      this.windowManager.addListener('add', this.onWindowAdded)
      this.windowManager.addListener('remove', this.onWindowRemoved)
      this.windowManager.taskbar = this
    }
    this.updateWindowList()
  },

  onWindowAddHandler : function(e) {
    var w = e.window
    this.addWindow(w)
  },

  onWindowRemoveHandler : function(e) {
    var w = e.window
    this.removeWindow(w)
  },

  addWindow : function(w) {
    if (!w.showInTaskbar) return
    if (!this.windowGroups[w.group])
      this.createWindowGroup(w.group)
    w.addListener('groupChange', this.onWindowGroupChanged)
    this.windowGroups[w.group].addWindow(w)
  },

  removeWindow : function(w) {
    if (!this.windowGroups[w.group]) return
    this.windowGroups[w.group].removeWindow(w)
    w.removeListener('groupChange', this.onWindowGroupChanged)
    if (this.windowGroups[w.group].isEmpty())
      this.removeWindowGroup(w.group)
  },

  onWindowGroupChangeHandler : function(e) {
    var og = e.old_value
    var w = e.target
    if (this.windowGroups[og]) {
      this.windowGroups[og].removeWindow(w)
      if (this.windowGroups[og].isEmpty())
        this.removeWindowGroup(og)
    }
    w.removeListener('groupChange', this.onWindowGroupChanged)
    this.addWindow(w)
  },

  updateWindowList : function() {
    this.clearWindowGroups()
    this.windowManager.windows.each(this.addWindow.bind(this))
  },

  clearWindowGroups : function() {
    this.windowGroups.each(function(kv) {
      this.removeWindowGroup(kv[0])
    }.bind(this))
  },

  createWindowGroup : function(name) {
    if (this.windowGroups[name]) return false
    var wg = new Applets.Taskbar.WindowGroup(name, this)
    wg.addListener('titleChange', function(e){
      delete this.windowGroups[e.old_value]
      if (!this.windowGroups[e.value])
        this.windowGroups[e.value] = e.target
      else
        this.contentElement.removeChild(e.target.element)
    }.bind(this))
    this.windowGroups[name] = wg
    this.contentElement.appendChild(wg.element)
    return wg
  },

  removeWindowGroup : function(name) {
    if (name == 'default') return
    var wg = this.windowGroups[name]
    this.contentElement.removeChild(wg.element)
    delete this.windowGroups[name]
  }

}


Applets.Taskbar.WindowGroup = function(name, taskbar) {
  this.title = name
  this.taskbar = taskbar
  this.init()
  this.setTitle(name)
}
Applets.Taskbar.WindowGroup.prototype = {}
Object.extend(Applets.Taskbar.WindowGroup.prototype, Enumerable)
Object.extend(Applets.Taskbar.WindowGroup.prototype, EventListener)
Object.extend(Applets.Taskbar.WindowGroup.prototype, {
  collapsed : false,
  
  init : function() {
    this.windows = []
    this.initElements()
    this.initEventListeners()
  },

  initElements : function() {
    this.element = E('div', null, null, 'windowGroup')
    this.titleElement = E('h3', null, null, 'windowGroupTitle')
    this.appletListElement = E('ul', null, null, 'windowGroupAppletList')
    this.listElement = E('ul', null, null, 'windowList')
    if (this.title != 'default') 
      this.element.appendChild(this.titleElement)
    this.element.appendChild(this.appletListElement)
    this.element.appendChild(this.listElement)
  },

  initEventListeners : function() {
    this.titleElement.windowGroup = this
    Desk.Draggable.makeDraggable(this.titleElement)
    Desk.Droppable.makeDroppable(this.titleElement)
    Desk.Droppable.makeDroppable(this.appletListElement)
    Desk.Droppable.makeDroppable(this.listElement)
    this.titleElement.drop = this.dropTitle.bind(this)
    this.appletListElement.drop = this.dropList.bind(this)
    this.listElement.drop = this.dropList.bind(this)
    this.titleElement.addEventListener('dblclick', function(ev) {
      this.collapse()
      Event.stop(ev)
    }.bind(this), false)
    this.titleElement.addEventListener('mousedown', function(ev) {
      Event.stop(ev)
    }.bind(this), false)
    this.menu = new Desk.Menu()
    this.menu.addTitle(Tr('Applets.Taskbar.window_group'))
    this.menu.addItem(Tr('Applets.Taskbar.collapsed'), this.collapse.bind(this))
    this.menu.uncheckItem(Tr('Applets.Taskbar.collapsed'))
    this.addListener('collapseChange', function(e){
      if (e.value)
        this.menu.checkItem(Tr('Applets.Taskbar.collapsed'))
      else
        this.menu.uncheckItem(Tr('Applets.Taskbar.collapsed'))
    }.bind(this))
    this.menu.addSeparator()
    this.menu.addItem(Tr('Applets.Taskbar.rename'), this.makeEditable.bind(this))
    this.menu.addSeparator()
//     this.menu.addItem(Tr('Applets.Taskbar.duplicate'), this.duplicate.bind(this))
    this.menu.addItem(Tr('Applets.Taskbar.close_all'), this.close.bind(this), 'icons/Remove.png')
    this.menu.bind(this.titleElement)
  },

  close : function() {
    while(!this.windows.isEmpty())
      this.windows[0].close()
  },

  collapse : function() {
    this.setCollapsed(!this.collapsed)
  },

  duplicate : function() {
    var new_name = this.taskbar.createUniqueGroupName(this.title)
    var new_wg = this.taskbar.createWindowGroup(new_name)
    this.each(function(w){ w.duplicate().setGroup(new_name) })
    return new_wg
  },

  makeEditable : function() {
    Element.replaceWithEditor(this.titleElement, this.setTitle.bind(this))
  },

  isEmpty : function() {
    return this.windows.isEmpty()
  },

  each : function(iterator) {
    return this.windows.each(iterator)
  },

  setTitle : function(title) {
    this.titleElement.innerHTML = title
    var ov = this.title
    this.title = title
    this.newEvent('titleChange', {old_value: ov, value: title})
    this.windows.map().each(function(w){ w.setGroup(title) })
  },

  setCollapsed : function(new_value) {
    var ov = this.collapsed
    this.collapsed = new_value
    this.listElement.style.display = (this.collapsed ? 'none' : null)
    this.each(function(w){ w.setGroupCollapsed(new_value) })
    this.newEvent('collapseChange', {old_value: ov, value: new_value})
  },

  addWindow : function(w) {
    if (this.windows.include(w)) return
    this.windows.push(w)
    var li = E('li', null, null, 'windowListEntry')
    li.appendChild(w.taskbarElement)
    this.listElement.appendChild(li)
    w.setGroupCollapsed(this.collapsed)
  },

  removeWindow : function(w) {
    var i = this.windows.indexOf(w)
    if (i < 0) return
    this.listElement.removeChild(this.listElement.childNodes[i])
    this.windows.deleteFirst(w)
  },

  dropTitle : function(dragged, e) {
    if (dragged.className.match(/\bwindowTaskbarEntry\b/)) {
      dragged.window.setGroup(this.title)
    } else if (dragged.className.match(/\bwindowGroupTitle\b/)) {
      if (this != dragged.windowGroup) {
        while(!dragged.windowGroup.isEmpty())
          dragged.windowGroup.windows[0].setGroup(this.title)
      }
    }
  },
  
  dropList : function(dragged, e) {
    if (dragged.className.match(/\bwindowTaskbarEntry\b/)) {
      dragged.window.setGroup(this.title)
    } else if (dragged.className.match(/\bwindowGroupTitle\b/)) {
      if (this != dragged.windowGroup) {
        this.element.parentNode.insertBefore(
          dragged.windowGroup.element,
          this.element.nextSibling)
      }
    }
  }
})
