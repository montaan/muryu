Selection = function() {
  this.items = new Hash()
}
Selection.prototype = {
  lastSelected : null,
  
  oncontextmenu : function(ev) {
    if (!ev.ctrlKey) {
      var menu = new Desk.Menu()
      menu.addTitle(Tr('Selection'))
      menu.addItem(Tr('Selection.add_to_playlist'), this.selection.addToPlaylist.bind(this.selection))
      menu.addItem(Tr('Selection.create_presentation'))
      menu.addSeparator()
      menu.addItem(Tr('Selection.makePublic'), this.selection.makePublic.bind(this.selection))
      menu.addItem(Tr('Selection.makePrivate'), this.selection.makePrivate.bind(this.selection))
      menu.addSeparator()
      menu.addItem(Tr('Selection.delete_all'), this.selection.deleteSelected.bind(this.selection))
      menu.addItem(Tr('Selection.undelete_all'), this.selection.undeleteSelected.bind(this.selection))
      menu.addSeparator()
      menu.addItem(Tr('Selection.deselect'), function() { this.selection.deselect(this.item) }.bind(this))
      menu.addItem(Tr('Selection.clear'), this.selection.clear.bind(this.selection))
      menu.skipHide = true
      menu.show(ev)
      Event.stop(ev)
    }
  },

  deselect : function(obj) {
    if (!this.items[obj.itemHREF]) return
    var s = this.items[obj.itemHREF]
    delete this.items[obj.itemHREF]
    if (s.ondeselect) s.ondeselect()
    this.lastSelected = s
  },

  select : function(obj) {
    if (this.items[obj.itemHREF]) return
    this.items[obj.itemHREF] = obj
    if (obj.onselect) obj.onselect()
    this.lastSelected = obj
  },
  
  toggle : function(obj) {
    if (this.items[obj.itemHREF]) {
      this.deselect(obj)
    } else {
      this.select(obj)
    }
  },

  clear : function() {
    this.items.values().each(this.deselect.bind(this))
  },
  
  spanTo : function(obj) {
    if (this.lastSelected) {
      this.findSpan(this.lastSelected, obj).each(this.toggle.bind(this))
    } else {
      this.toggle(obj)
    }
  },
  
  findSpan : function(from, to) {
    return []
  },
  
  deleteSelected : function() {
    this.items.values().invoke('deleteItem')
  },
  
  undeleteSelected : function() {
    this.items.values().invoke('undelete')
  },

  addToPlaylist : function() {
    this.items.values().invoke('addToPlaylist')
  },
  
  makePublic : function() {
    this.items.values().invoke('makePublic')
  },

  makePrivate : function() {
    this.items.values().invoke('makePrivate')
  },

  addTags : function(tags) {
    this.items.values().invoke('addTags', tags)
  },
  
  removeTags : function(tags) {
    this.items.values().invoke('removeTags', tags)
  },
  
  setTags : function(tags) {
    this.items.values().invoke('setTags', tags)
  },
  
  addGroups : function(groups) {
    this.items.values().invoke('addGroups', groups)
  },
  
  removeGroups : function(groups) {
    this.items.values().invoke('removeGroups', groups)
  },
  
  setGroups : function(groups) {
    this.items.values().invoke('setGroups', groups)
  },
  
  addSets : function(sets) {
    this.items.values().invoke('addSets', sets)
  },
  
  removeSets : function(sets) {
    this.items.values().invoke('removeSets', sets)
  },
  
  setSets : function(sets) {
    this.items.values().invoke('setSets', sets)
  }
  
}
