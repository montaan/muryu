Tr.addTranslations('en-US', {
  'TileMap.DblClickToEditTitle' : 'Double-click to edit search terms',
  'TileMap' : 'Search',
  'TileMap.Refresh' : 'Refresh',
  'TileMap.EditTitle' : 'Edit search terms',
  'TileMap.RemoveMap' : 'Remove search',
  'TileMap.ShowColors' : 'Color items',
  'TileMap.ShowStats' : 'Open stats window',
  'TileMap.itemCount' : function(count) { return count + ' items' },
  'Item.open' : 'Open',
  'Item.select' : 'Select',
  'Item.click_to_inspect' : 'Left-click to inspect ',
  'Item.add_to_playlist' : 'Add to playlist',
  'Item.play' : 'Play',
  'Item.view_in_slideshow' : 'View in slideshow',
  'Item.makePublic' : 'Make public',
  'Item.makePrivate' : 'Make private',
  'Item.NewGroups' : 'New Group(s)',
  'Item.NewSets' : 'New Folder(s)',
  'Selection' : 'Selection',
  'Selection.clear' : 'Clear selection',
  'Selection.deselect' : 'Deselect',
  'Selection.makePublic' : 'Make public',
  'Selection.makePrivate' : 'Make private',
  'Selection.addGroups' : 'Add groups',
  'Selection.addSets' : 'Add to folders',
  'Selection.delete_all' : 'Delete all',
  'Selection.undelete_all' : 'Undelete all',
  'Selection.add_to_playlist' : 'Add to playlist',
  'Selection.create_presentation' : 'Create presentation'
})
Tr.addTranslations('fi-FI', {
  'TileMap.DblClickToEditTitle' : 'Kaksoisnapsauta muokataksesi hakua',
  'TileMap' : 'Haku',
  'TileMap.Refresh' : 'Päivitä',
  'TileMap.EditTitle' : 'Muokkaa hakua',
  'TileMap.RemoveMap' : 'Poista haku',
  'TileMap.ShowColors' : 'Väritä tiedostot',
  'TileMap.ShowStats' : 'Seuraa latauksia',
  'TileMap.itemCount' : function(count) { return count + ' tiedostoa' },
  'Item.open' : 'Avaa',
  'Item.select' : 'Valitse',
  'Item.click_to_inspect' : 'Napsauta nähdäksesi ',
  'Item.add_to_playlist' : 'Lisää soittolistaan',
  'Item.play' : 'Soita',
  'Item.view_in_slideshow' : 'Näytä kuvaesityksessä',
  'Item.makePublic' : 'Tee julkiseksi',
  'Item.makePrivate' : 'Tee yksityiseksi',
  'Item.NewGroups' : 'Luo ryhmiä',
  'Item.NewSets' : 'Luo kansioita',
  'Selection' : 'Valinta',
  'Selection.clear' : 'Tyhjennä valinta',
  'Selection.deselect' : 'Poista valinnasta',
  'Selection.makePublic' : 'Tee julkiseksi',
  'Selection.makePrivate' : 'Tee yksityiseksi',
  'Selection.addGroups' : 'Lisää ryhmiin',
  'Selection.addSets' : 'Lisää kansioihin',
  'Selection.delete_all' : 'Poista kaikki',
  'Selection.undelete_all' : 'Tuo kaikki takaisin',
  'Selection.add_to_playlist' : 'Lisää soittolistaan',
  'Selection.create_presentation' : 'Luo esitys'
})


ItemArea = {
  deleteItem : function() {
    new Ajax.Request(this.itemHREF.replace(/json$/, 'delete'), {
      onSuccess : function() {
        this.getMap().forceUpdate()
      }.bind(this)
    })
  },
  
  undelete : function() {
    new Ajax.Request(this.itemHREF.replace(/json$/, 'undelete'), {
      onSuccess : function() {
        this.getMap().forceUpdate()
      }.bind(this)
    })
  },

  edit : function() {
    new Desk.Window(this.itemHREF.replace(/json$/, 'edit'))
  },

  imageExts : ['jpeg','jpg','png','gif','crw','nef','tiff','psd','bmp','cr2','raf','orf','dng','pef'],
  
  defaultAction : function() {
    var ext = this.getExt()
    if (this.imageExts.include(ext)) {
//       this.open()
      this.viewInSlideshow()
    } else if ( MusicPlayer && MusicPlayer.sound && ext == 'mp3' ) {
      MusicPlayer.addToPlaylist(this.href)
      MusicPlayer.goToIndex(MusicPlayer.playlist.length - 1)
    } else if (ext == 'html') {
      window.open(this.href, '_tab')
    } else {
      this.open()
    }
  },

  secondaryAction : function() {
    var ext = this.getExt()
    if (this.imageExts.include(ext)) {
      this.open()
//       this.viewInSlideshow()
    } else {
      this.open()
    }
  },
  
  open : function() {
    new Desk.Window(this.itemHREF)
  },

  getTitle : function() {
    return Tr('Item.click_to_inspect', this.info.path.toString().split("/").last())
  },

  toggleSelect : function() {
    this.getMap().selection.toggle(this)
  },

  select : function() {
    this.getMap().selection.select(this)
  },

  deselect : function() {
    this.getMap().selection.deselect(this)
  },

  getExt : function() {
    return this.href.split(".").last().toString().toLowerCase()
  },

  addToPlaylist : function() {
    if (MusicPlayer && this.getExt() == 'mp3')
      MusicPlayer.addToPlaylist(this.href)
  },
  
  viewInSlideshow : function() {
    var m = document
    if (m.slideshowWindow) {
      if (!m.slideshowWindow.windowManager) {
        m.slideshowWindow.setWindowManager(Desk.Windows)
        if (m.slideshowWindow.maximized)
          m.slideshowWindow.maximize()
      }
      var map = this.getMap()
      if (m.slideshowWindow.slideshow.query.q != map.query) {
        m.slideshowWindow.slideshow.setQuery({q:map.query||''}, false)
      }
      if (m.slideshowWindow.minimized)
        m.slideshowWindow.minimize()
      if (m.slideshowWindow.shaded)
        m.slideshowWindow.shade()
      m.slideshowWindow.slideshow.showIndex(this.info.index)
    } else {
      new Desk.Window('app:Suture.loadWindow', {
        parameters: {index:this.info.index, query:{ q:this.getMap().query||'' }}
      })
    }
  },

  setSets : function(sets, created) {
    var params = {'sets' : sets, 'sets.new' : created}
    this.editItem(params)
  },

  setGroups : function(groups, created) {
    var params = {'groups' : groups, 'groups.new' : created}
    this.editItem(params)
  },

  addGroups : function(groups, created) {
    if (created && created.length > 0)
      groups = groups.concat(created.split(","))
    var params = {'groups.new' : groups}
    this.editItem(params)
  },

  addSets : function(sets, created) {
    if (created && created.length > 0)
      sets = sets.concat(created.split(","))
    var params = {'sets.new' : sets}
    this.editItem(params)
  },

  editItem : function(params) {
    new Ajax.Request(this.itemHREF.replace(/json$/,'edit'), {
      method: 'post',
      parameters : params,
      onSuccess : function(res) {
        if (params['sets.new'] && params['sets.new'].length > 0)
          Sets.update()
        if (params['groups.new'] && params['groups.new'].length > 0)
          Groups.update()
        this.info = res.responseText.evalJSON()
      }.bind(this)
    })
  },
  
  fillSetMenu : function(menu) {
    if (this.info.sets) {
      if (menu.element.firstChild)
        menu.element.removeChild(menu.element.firstChild)
      menu.addTitle(Tr('Item.sets'))
      for (var i=0; i<Sets.length; i++) {
        var n = Sets[i].name + ' ('+Sets[i].namespace+')'
        menu.addItem(n, function(ev){
          this.toggle()
          menu.skipHide = true
          Event.stop(ev)
        }, null, Sets[i].namespace + '/' + Sets[i].name)
        if (this.info.sets.include(Sets[i].namespace + '/' + Sets[i].name))
          menu.checkItem(n)
        else
          menu.uncheckItem(n)
        if (!Sets[i].writable)
          menu.disableItem(n)
      }
      menu.addTitle(Tr('Item.NewSets'))
      this.addSubMenuCallback(menu, this.setSets.bind(this))
    } else {
      menu.addTitle(Tr('Loading'))
      this.addInfoCallback(this.fillSetMenu, menu)
    }
    if (!this.loadingInfo)
      this.loadInfo()
  },

  fillGroupMenu : function(menu) {
    if (this.info.groups) {
      if (menu.element.firstChild)
        menu.element.removeChild(menu.element.firstChild)
      menu.addTitle(Tr('Item.groups'))
      for (var i=0; i<Groups.length; i++) {
        var n = Groups[i].name + ' ('+Groups[i].owner+')'
        menu.addItem(n, function(ev){
          this.toggle()
          menu.skipHide = true
          Event.stop(ev)
        }, null, Groups[i].name)
        if (this.info.groups.include(Groups[i].name))
          menu.checkItem(n)
        else
          menu.uncheckItem(n)
        if (!this.info.writable)
          menu.disableItem(n)
      }
      if (this.info.writable) {
        menu.addTitle(Tr('Item.NewGroups'))
        this.addSubMenuCallback(menu, this.setGroups.bind(this))
      }
    } else {
      menu.addTitle(Tr('Loading'))
      this.addInfoCallback(this.fillGroupMenu, menu)
    }
    if (!this.loadingInfo)
      this.loadInfo()
  },

  addSubMenuCallback : function(menu, callback) {
    var newInput = E('input', null, null, null, {
      display : 'block', marginLeft : '1ex', marginRight : '1ex'
    }, {
      type : 'text'
    })
    $(menu.element).append(newInput)
    var oldItems = menu.checkedItems().pluck('itemValue')
    menu.addListener('hide', function(){
      var newItems = menu.checkedItems().pluck('itemValue')
      var created = newInput.value
      if (!oldItems.equals(newItems) || created.length > 0) {
        callback(newItems, created)
      }
    })
  },

  loadInfo : function() {
    this.loadingInfo = true
    new Ajax.Request(this.itemHREF, {
      method: 'get',
      onSuccess : function(res) {
        this.info = res.responseText.evalJSON()
        if (this.infoCallbacks)
          for (var i=0; i<this.infoCallbacks.length; i++)
            this.infoCallbacks[i][0].apply(this, this.infoCallbacks[i].slice(1))
      }.bind(this)
    })
  },

  addInfoCallback : function() {
    if (!this.infoCallbacks)
      this.infoCallbacks = []
    this.infoCallbacks.push($A(arguments))
  },

  oncontextmenu : function(ev) {
    if (!ev.ctrlKey) {
      var menu = new Desk.Menu()
      menu.addTitle(decodeURI(this.href).split("/").last())
      var ext = this.getExt()
      if (ext == 'mp3' && MusicPlayer) {
        menu.addItem(Tr('Item.add_to_playlist'), this.addToPlaylist.bind(this))
        menu.addItem(Tr('Item.play'), function(){
          this.addToPlaylist()
          MusicPlayer.goToIndex(MusicPlayer.playlist.length - 1)
        }.bind(this))
        menu.addSeparator()
      } else if (ext.match(/^(jpe?g|png|gif)$/)) {
        menu.addItem(Tr('Item.view_in_slideshow'), this.viewInSlideshow.bind(this))
        menu.addSeparator()
      }
      menu.addItem(Tr('Item.open'), this.open.bind(this))
      menu.addItem(Tr('Item.select'), this.toggleSelect.bind(this))
      menu.addSeparator()
      menu.addItem(Tr('Button.Item.edit'), this.edit.bind(this))
      menu.addSeparator()
      menu.addSubMenu(Tr('Item.sets'), this.fillSetMenu.bind(this))
      menu.addSeparator()
      menu.addItem(Tr('Item.makePublic'), this.makePublic.bind(this))
      menu.addItem(Tr('Item.makePrivate'), this.makePrivate.bind(this))
      menu.addSubMenu(Tr('Item.groups'), this.fillGroupMenu.bind(this))
      menu.addSeparator()
      if (this.info.deleted)
        menu.addItem(Tr('Button.Item.undelete_item'), this.undelete.bind(this))
      else
        menu.addItem(Tr('Button.Item.delete_item'), this.deleteItem.bind(this))
      menu.skipHide = true
      menu.show(ev)
      Event.stop(ev)
    }
  },

  makePublic : function() {
    new Ajax.Request(this.itemHREF.replace(/json$/, 'make_public'), {
      onSuccess : function(res) {
        this.deselect()
      }.bind(this)
    })
  },

  makePrivate : function() {
    new Ajax.Request(this.itemHREF.replace(/json$/, 'make_private'), {
      onSuccess : function(res) {
        this.deselect()
      }.bind(this)
    })
  },

  onclick : function(ev) {
    if (Event.isLeftClick(ev)) {
      if (this.Xdown == undefined ||
          (Math.abs(this.Xdown - ev.clientX) < 3 &&
           Math.abs(this.Ydown - ev.clientY) < 3)
      ) {
        this.Xdown = this.Ydown = undefined
        if (ev.ctrlKey) {
          return
        } else if (ev.shiftKey) {
          this.toggleSelect()
        } else if (ev.altKey) {
          return
/*        } else if (this.actionTimeout) {
          clearTimeout(this.actionTimeout)
          delete this.actionTimeout
          Event.stop(ev)
        } else {
          Event.stop(ev)
          this.actionTimeout = setTimeout(function(){
            delete this.actionTimeout
            this.defaultAction()
          }.bind(this), 300)*/
        }
      }
      Event.stop(ev)
    }
  },

  ondblclick : function(ev) {
    if (Event.isLeftClick(ev)) {
      if (this.actionTimeout) {
        clearTimeout(this.actionTimeout)
        delete this.actionTimeout
      }
      var m = this.getMap()
      var t = m.root
      var maps_per_container = t.container.offsetWidth / Math.max(m.width, m.height)
      var crop_z = Math.floor(Math.log(maps_per_container) / Math.log(2))
      var dz = t.z - (m.z+m.relativeZ)
      if (crop_z > 4)
        crop_z = 7
      var full_z = Math.floor(Math.log(Math.max(t.container.offsetWidth, t.container.offsetHeight)) / Math.log(2))
      if (crop_z+dz > t.targetZ) {
        t.animatedZoom(crop_z+dz)
      } else {
        if (t.targetZ < 7+dz) {
          t.animatedZoom(7+dz)
        } else if (t.targetZ < full_z+dz) {
          if (this.imageExts.include(this.href.split(".").last()))
            t.animatedZoom(full_z+dz)
          else
            this.defaultAction()
        } else {
          t.animatedZoom(7+dz)
        }
      }
      Event.stop(ev)
    }
  },

  onmousedown : function(ev) {
    if (Event.isLeftClick(ev)) {
      this.Xdown = ev.clientX
      this.Ydown = ev.clientY
    }
  },

  getTile : function() {
    if (this.parentNode && this.parentNode.parentNode)
      return this.parentNode.parentNode.tile || this.parentNode.parentNode
  },

  getMap : function() {
    return this.getTile().map
  },
  
  onselect : function() {
    var tile = this.getTile()
    var fac = Math.pow(2, tile.z)
    var s = new SelectionArea({
      left : (tile.left + this.info.x) / fac,
      top : (tile.top + this.info.y) / fac,
      width : this.info.sz / fac,
      height : this.info.sz / fac,
      parent : tile.map.selectionLayer
    })
    this.selectionIndicator = s
    s.element.selection = tile.map.selection
    s.element.item = this
    s.element.style.backgroundColor = 'cyan'
    s.element.style.opacity = 0.5
    s.element.onmousedown = function(e) {
      this.downX = e.clientX
      this.downY = e.clientY
    }
    s.element.onclick = function(e) {
      if (Event.isLeftClick(e) &&
          (this.downX == undefined || this.downY == undefined) ||
          (Math.abs(this.downX - e.clientX) < 3 &&
           Math.abs(this.downY - e.clientY) < 3   )
      ) {
        if (e.shiftKey) {
          this.item.toggleSelect()
        } else {
          this.selection.clear()
        }
        Event.stop(e)
      }
    }
    s.element.oncontextmenu = s.element.selection.oncontextmenu
  },
  
  ondeselect : function() {
    this.selectionIndicator.detachSelf()
  }
  
}

