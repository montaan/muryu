Tr.addTranslations('en-US', {
  'Applets.Applet' : 'Applet',
  'Applets.Remove' : 'Remove applet',
  'Applets.Session' : 'Session',
  'Applets.Session.save' : 'Save session now',
  'Applets.Session.autosave' : 'Autosave',
  'Applets.Session.clear' : 'Clear session',
  'Applets.Session.Welcome' : function(name) { return 'Welcome, '+name+'!' },
  'Applets.Session.LogOut' : 'Log out',
  'Applets.Session.LogIn' : 'Log in',
  'Applets.Session.Register' : 'Register new account',
  'Applets.Session.AccountName' : 'Account name',
  'Applets.Session.Password' : 'Password',
  'Applets.Session.Upload' : 'Upload',
  'Applets.Session.UploadItems' : 'Upload items',
  'Applets.Session.FirefoxExtension' : 'Firefox add-on',
  'Applets.Session.Settings' : 'Settings',
  'Applets.Session.BackgroundColor' : 'Background color',
  'Button.Applets.Session.ToggleColors' : 'Toggle colors',
  'Applets.MusicPlayer' : 'Player',
  'Applets.MusicPlayer.Playlist' : 'Playlist'
})
Tr.addTranslations('fi-FI', {
  'Applets.Applet' : 'Sovelma',
  'Applets.Remove' : 'Poista sovelma',
  'Applets.Session' : 'Istunto',
  'Applets.Session.save' : 'Tallenna istunto',
  'Applets.Session.autosave' : 'Automaattinen tallennus',
  'Applets.Session.clear' : 'Pyyhi istunto',
  'Applets.Session.Welcome' : function(name) { return 'Tervetuloa, '+name+'!' },
  'Applets.Session.LogOut' : 'Kirjaudu ulos',
  'Applets.Session.LogIn' : 'Kirjaudu sisään',
  'Applets.Session.Register' : 'Luo uusi tunnus',
  'Applets.Session.AccountName' : 'Tunnuksesi',
  'Applets.Session.Password' : 'Salasana',
  'Applets.Session.Upload' : 'Tiedostot',
  'Applets.Session.UploadItems' : 'Tuo tiedostoja',
  'Applets.Session.FirefoxExtension' : 'Firefoxin lisäosa',
  'Applets.Session.Settings' : 'Asetukset',
  'Applets.Session.BackgroundColor' : 'Taustaväri',
  'Button.Applets.Session.ToggleColors' : 'Värien näyttö',
  'Applets.MusicPlayer' : 'Soitin',
  'Applets.MusicPlayer.Playlist' : 'Soittolista'
})



Applets = {
  bakeAppletMenu: function(applet) {
    applet.menu.addTitle(Tr('Applets.Applet'))
    applet.menu.addItem(Tr('Applets.Remove'), function(){
      applet.panel.removeApplet(applet)
    }, 'icons/Remove.png')
    applet.menu.bind(applet)
  }
}


Applets.Session = function(wm) {
  if (!wm) wm = Desk.Windows
  var c = E('span', null, null, 'taskbarApplet Session')
  var title = E('h4', Tr('Applets.Session'), null, 'windowGroupTitle')
  var controls = E('div')

  var logout = E('p', A('/users/logout', Tr('Applets.Session.LogOut')))
  logout.onclick = function(){ c.autosaveSession() }

  var loginform = E('form')
  loginform.method='POST'
  loginform.action='/users/login'
  loginform.appendChild(E('h5', Tr('Applets.Session.LogIn'), null, 'windowGroupTitle'))
  loginform.appendChild(E('h5', Tr('Applets.Session.AccountName'), null, 'taskbarFormTitle'))
  var username = E('input', null, null, 'taskbarTextInput')
  username.name = 'username'
  username.type = 'text'
  loginform.appendChild(username)
  loginform.appendChild(E('h5', Tr('Applets.Session.Password'), null, 'taskbarFormTitle'))
  var password = E('input', null, null, 'taskbarTextInput')
  password.name = 'password'
  password.type = 'password'
  loginform.appendChild(password)
  var submit = E('input', null, null, 'taskbarSubmitInput')
  submit.value = Tr('Log in')
  submit.type = 'submit'
  loginform.appendChild(submit)
  
  c.loggedIn = (Session.storage.info.name && Session.storage.info.name != 'anonymous')
  
  if (c.loggedIn) {
    controls.appendChild(E('p', Tr('Applets.Session.Welcome', Session.storage.info.name)))
    controls.appendChild(logout)
    controls.appendChild(E('h5', Tr('Applets.Session.Upload'), null, 'windowGroupTitle'))
    controls.appendChild(E('p', A('/items', Tr('Applets.Session.UploadItems'))))
    controls.appendChild(E('p', A('muryu_uploader.xpi', Tr('Applets.Session.FirefoxExtension'))))
  } else {
    controls.appendChild(loginform)
    controls.appendChild(E('p', A('/users/register', Tr('Applets.Session.Register'))))
  }
  controls.appendChild(E('h5', Tr('Applets.Session.Settings'), null, 'windowGroupTitle'))
  var colorToggles = E('p', 'BG [ ')
  var colors = {
    flint: '13191C',
    blue: '03233C',
    purple: '231323'
  }
  for (var i in colors) {
    var a = A("javascript:void(Map.setBgcolor('"+colors[i]+"'))", i)
    colorToggles.appendChild(a)
    colorToggles.appendChild(T(' | '))
  }
  colorToggles.removeChild(colorToggles.lastChild)
  colorToggles.appendChild(T(' ]'))
  controls.appendChild(colorToggles)
  
  c.appendChild(title)
  c.appendChild(controls)

  c.session = null
  c.autosave = true
  c.toggleAutosave = function(){
    this.setAutosave(!this.autosave)
  }
  c.setAutosave = function(d){
    this.autosave = d
    if (this.autosave) {
      this.menu.checkItem(Tr('Applets.Session.autosave'))
    } else {
      this.menu.uncheckItem(Tr('Applets.Session.autosave'))
    }
  }
  c.autosaveSession = function(){
    if (this.autosave && this.sessionChanged)
      this.saveSession()
  }
  c.saveSession = function(){
    if (this.loggedIn) {
      this.sessionChanged = false
      Session.save()
    }
  }
  c.clearSession = function(){
    if (this.loggedIn) {
      this.sessionChanged = false
      Session.clear()
      this.loggedIn = false
      document.location.reload()
    }
  }
  c.dumpSession = function(){
    return {loader: 'Applets.Session', data: ''}
  }
  c.signalSessionChange = function() {
    c.sessionChanged = true
  }

  wm.addListener('addWindow', function(e){
    if (e.value.avoid) {
      e.addListener('addApplet', c.signalSessionChange)
      e.addListener('removeApplet', c.signalSessionChange)
    }
    c.signalSessionChange()
  })
  wm.addListener('removeWindow', function(e){
    if (e.value.avoid) {
      e.removeListener('addApplet', c.signalSessionChange)
      e.removeListener('removeApplet', c.signalSessionChange)
    }
    c.signalSessionChange()
  })
  c.autosaveInterval = setInterval(c.autosaveSession.bind(c), 5*60*1000) 
  window.addEventListener('unload', c.saveSession.bind(c), false)
  c.menu = new Desk.Menu()
  c.menu.addTitle(Tr('Applets.Session'))
  c.menu.addItem(Tr('Applets.Session.save'), c.saveSession.bind(c))
  c.menu.addItem(Tr('Applets.Session.autosave'), c.toggleAutosave.bind(c))
  c.menu.checkItem(Tr('Applets.Session.autosave'))
  c.menu.addSeparator()
  c.menu.addItem(Tr('Applets.Session.clear'), c.clearSession.bind(c))
  Applets.bakeAppletMenu(c)

  return c
}
Applets.Session.loadSession = function(dump) {
  return Applets.Session()
}


Applets.OpenURL = function(wm) {
  if (!wm) wm = Desk.Windows
  var c = E('span', null,null, 'taskbarApplet OpenURL')
  c.dumpSession = function(){
    return {loader: 'Applets.OpenURL', data: ''}
  }
  var f = E('form', null,null, 'taskbarForm')
  var title = E('h4', 'Open URL', null, 'windowGroupTitle')
//   Draggable.makeDraggable(title)
  var t = E('input',null,null,'taskbarTextInput',null,
    {type:'text'})
  var s = E('input',null,null,'taskbarSubmitInput',null,
    {type:'submit', value:'Open'})
  c.appendChild(title)
  c.appendChild(f)
  f.appendChild(t)
  f.appendChild(s)
  c.openURL = function(new_src) {
    if (new_src.length > 0) {
      if (new_src[0] == '/')
        new_src = 'file://' + new_src
      if (!new_src.match(/^(\.|[a-z]+:)/i))
        new_src = 'http://' + new_src
      var mt = Mime.guess(new_src).mimetype
      var w = new Desk.Window(new_src, {
        group: mt.capitalize(),
        minimized: (soundManager && soundManager.enabled && mt == 'music')
      })
    }
  }
  t.addEventListener('focus', function(e){
    this.select()
  }, false)
  f.addEventListener('submit', function(e){
    var new_src = t.value.toString()
    f.blur()
    Event.stop(e)
    c.openURL(new_src)
  }, false)
  c.menu = new Desk.Menu()
  Applets.bakeAppletMenu(c)
  return c
}
Applets.OpenURL.loadSession = function(dump) {
  return Applets.OpenURL()
}


Desk.Slider = function(callback) {
  var px = 1 / 6
  var e = E('div', null, null, 'slider')
  e.style.cursor = 'pointer'
  e.knob = E('div', null, null, 'sliderKnob')
  e.loaded = E('div', null, null, 'sliderLoaded')
  e.onmousedown = function(ev) {
    var lx = ev.layerX
    if (ev.target == this.knob || ev.target == this.loaded) lx += 1
    else lx -= 4
    this.setPosition(lx / this.offsetWidth)
  }
  e.appendChild(e.loaded)
  e.appendChild(e.knob)
  Object.extend(e, EventListener)
  e.position = 0
  e.setPosition = function(val, sendEvent) {
    this.position = Math.min(Math.max(0, val), 1)
    this.knob.style.width = (val * (this.offsetWidth-2)) + 'px'
    if (sendEvent != false)
      this.newEvent('valueChanged', { value: val })
  }
  e.setLoaded = function(val) {
    this.loaded.style.width = (val * (this.offsetWidth-2)) + 'px'
  }
  if (callback)
    e.addListener('valueChanged', function(e) { callback(e.value) })
  return e
}


MusicPlayer = null
Applets.MusicPlayer = function() {
  var c = E('span', null,null, 'taskbarApplet MusicPlayer')
  var title = E('h4', Tr('Applets.MusicPlayer'), null, 'windowGroupTitle')
  c.appendChild(title)
  MusicPlayer = c

  Object.extend(c, EventListener)
  c.playlist = []
  c.currentIndex = 0
  c.position = 0
  c.lastPos = 0
  c.savedSeek = 0
  c.volume = 100
  c.currentURL = null
  c.repeating = false
  c.shuffling = false
  c.soundID = 'currentMPSound'
  c.firstPlay = true

  c.addToPlaylist = function(item) {
    this.playlist.push(item)
    this.playlistChanged()
  }
  
  c.removeFromPlaylistAt = function(index) {
    this.playlist.splice(index, 1)
    this.playlistChanged()
  }
  
  c.playlistChanged = function() {
    this.newEvent('playlistChanged', { value: this.playlist })
  }
  
  c.next = function(){
    if (this.shuffling) {
      this.goToIndex(Math.floor(Math.random()*this.playlist.length))
    } else {
      this.goToIndex(this.currentIndex + 1)
    }
  }
  
  c.previous = function(){
    this.goToIndex(this.currentIndex - 1)
  }
  
  c.gotoFirst = function(startPlaying){
    this.goToIndex(0, startPlaying)
  }
  
  c.goToIndex = function(index, startPlaying){
    if (startPlaying == undefined) startPlaying = true
    index = parseInt(index) % this.playlist.length
    if (isNaN(index)) index = 0
    if (index < 0) index = this.playlist.length + index
    this.currentIndex = index
    this.savedSeek = 0
    if (startPlaying) this.play()
    else
      this.newEvent('songChanged', {value: (this.playlist[this.currentIndex] || '').split("/").last() })
  }
  
  c.playNext = function() {
    if (this.repeating)
      this.play()
    else
      this.next()
  }.bind(c)
  
  c.shuffle = function(){
    this.setShuffling(!this.shuffling)
  }
  
  c.setShuffling = function(v) {
    if (v != this.shuffling)
      this.shuffleButton.toggle()
    this.shuffling = v
    if (this.shuffling) this.menu.checkItem('Shuffle')
    else this.menu.uncheckItem('Shuffle')
  }
  
  c.repeat = function(){
    this.setRepeating(!this.repeating)
  }
  
  c.setRepeating = function(v) {
    if (v != this.repeating)
      this.repeatButton.toggle()
    this.repeating = v
    if (this.repeating) this.menu.checkItem('Repeat Song')
    else this.menu.uncheckItem('Repeat Song')
  }
  
  c.play = function(){
    if (!this.playlist.isEmpty()) {
      this.playing = true
      this.paused = false
      this.currentItem = this.playlist[this.currentIndex]
      if (this.currentItem) {
        this.currentURL = (typeof this.currentItem == 'string' ?
                           this.currentItem :
                           this.currentItem.src)
        var params = {url: this.currentURL, autoPlay: true, stream: true, volume: this.volume}
        soundManager.unload(this.soundID)
        soundManager.load(this.soundID, params)
        this.position = 0
      } else {
        setTimeout(this.playNext, 0)
      }
      this.newEvent('songChanged', {value: (this.currentURL || '').split("/").last() })
    } else {
      this.paused = true
      this.currentIndex = 0
      this.newEvent('songChanged', {value: ''})
    }
    this.updateButtons()
  }

  c.pause = function(){
    if (this.playing) {
      if (this.paused)
        soundManager.resume(this.soundID)
      else
        soundManager.pause(this.soundID)
      this.paused = !this.paused
      this.updateButtons()
    } else {
      this.play()
    }
  }
  
  c.stop = function() {
    if (this.playing) {
      soundManager.stop(this.soundID)
      this.playing = false
    }
    this.paused = false
    this.updateButtons()
  }
  
  c.updateButtons = function() {
    if (this.paused) {
      this.playButton.pull()
    } else {
      this.playButton.push()
    }
  }
  
  c.seekTo = function(pos) {
    this.position = 0
    this.lastPos = 0
    this.sound.setPosition(pos)
    this.newEvent('positionChanged', { value: Object.formatTime(pos) })
  }

  c.seekToPct = function(pct) {
    this.seekTo(parseInt(this.sound.durationEstimate * pct))
  }

  c.setVolume = function(vol) {
    this.volume = Math.min(100, Math.max(0, parseInt(vol)))
    if (isNaN(this.volume)) this.volume = 100
    if (this.sound)
      this.sound.setVolume(this.volume)
    this.newEvent('volumeChanged', {value: this.volume})
  }
  
  c.volumeUp = function() {
    this.setVolume(this.volume + 20)
  }
  
  c.volumeDown = function() {
    this.setVolume(this.volume - 20)
  }

  c.togglePlaylist = function(win) {
    if (this.playlistWindow) {
      if (this.playlistWindow.windowManager)
        this.playlistWindow.close()
      else
        this.playlistWindow.setWindowManager(Desk.Windows)
    } else {
      new Desk.Window('app:MusicPlayer.initPlaylistWindow')
    }
  }
  c.initPlaylistWindow = function(w) {
    this.playlistWindow = w
    w.setTitle(Tr('Applets.MusicPlayer.Playlist'))
    if (!w.width) {
      w.setSize(400, 400)
    }
    var pl = E('ol', null, 'MusicPlayer_playlist')
    var tlc = E('div', null)
    w.setContent(tlc)
    var t = this
    tlc.appendChild(Desk.Button('RemoveFromPlaylist', function() {
        for (var i=0; i<pl.childNodes.length; i++) {
          if (pl.childNodes[i].className == 'selected') {
            pl.removeChild(pl.childNodes[i])
            t.removeFromPlaylistAt(i)
            i--
          }
        }
    }, { showText: true, showImage: false }))
    tlc.appendChild(Desk.Button('SortPlaylist', function(){
    }, { showText: true, showImage: false }))

    var plc = E('div', null, 'MusicPlayer_playlistContainer')
    plc.style.overflow = 'auto'
    plc.style.width = '100%'
    plc.style.height = '100%'
    pl.getIndex = function(obj) {
      var c = this.childNodes
      for (var i=0; i<c.length; i++) {
        if (c[i] == obj) return i
      }
      return 0
    }
    pl.updateCurrent = function(val) {
      var idx = t.currentIndex
      var c = this.childNodes
      for (var i=0; i<c.length; i++) {
        if (i != idx)
          c[i].className = c[i].className.replace(/\s*\bcurrent\b/, '')
        else if (!c[i].className.match(/\s*\bcurrent\b/)) {
          c[i].className += ' current'
          this.current = c[i]
        }
      }
    }
    pl.updatePlaylist = function(val) {
      if (this.updated) {
        this.updated = false
      } else if ($A(this.childNodes).include(this.current)) {
        this.updated = true
        t.currentIndex = this.getIndex(this.current)
        t.playlistChanged()
      }
    }
    pl.currentUpdater = pl.updateCurrent.bind(pl)
    pl.playlistUpdater = pl.updatePlaylist.bind(pl)
    this.addListener('songChanged', pl.currentUpdater)
    this.addListener('playlistChanged', pl.playlistUpdater)
    pl.deselect = function() {
      var c = this.childNodes
      for (var i=0; i<c.length; i++) {
        c[i].className = c[i].className.replace(/\s*\bselected\b/, '')
      }
    }
    this.playlist.each(function(i) {
      var a = A(i, i.split('/').last())
      a.style.textDecoration = 'none'
      a.onclick = function(ev) { if (Event.isLeftClick(ev)) ev.preventDefault() }
      var li = E('li', a)
      li.ondblclick = function(ev) {
        t.goToIndex(pl.getIndex(this), true)
        Event.stop(ev)
      }
      li.onclick = function(ev) {
        if (Event.isLeftClick(ev)) {
          if (!ev.ctrlKey) pl.deselect()
          if (this.className.match(/\s*\bselected\b/))
            this.className = this.className.replace(/\s*\bselected\b/, '')
          else
            this.className += ' selected'
          Event.stop(ev)
        }
      }
      pl.appendChild(li)
    })
    pl.updateCurrent()
    plc.appendChild(pl)
    tlc.appendChild(plc)
    tlc.addEventListener('mousedown', function(){ w.bringToFront(); return true }, true)
    t.initSortable = function(){
      w.removeListener('containerChange', t.initSortable)
      Position.includeScrollOffsets = true
      Sortable.create('MusicPlayer_playlist', {
        scroll:'MusicPlayer_playlistContainer',
        onChange: function(){
          var new_pl = []
          $A(pl.childNodes).each(function(cn) {
            new_pl.push(cn.firstChild.href)
          })
          t.playlist = new_pl
          t.newEvent('playlistChanged', {value: t.playlist})
        }
      })
    }
    w.addListener('containerChange', t.initSortable)
  }

  soundManager.onload = function() {
    soundManager.createSound(c.soundID, {url: 'data/null.mp3'})
    c.sound = soundManager.sounds[c.soundID]
    c.sound.setVolume(c.volume)
    c.sound.options.onfinish = c.playNext
    c.sound.options.onplay = function() {
      c.setVolume(c.volume)
      c.updateButtons()
    }
    c.sound.options.whileplaying = function() {
      if (c.sound.volume != c.volume) c.sound.setVolume(c.volume)
      if (c.sound.position < c.lastPos) c.lastPos = c.sound.position
      c.position += c.sound.position - c.lastPos
      c.lastPos = c.sound.position
      c.newEvent('positionChanged', {
        pct: c.position < 0 ? 0 : (c.position / Math.max(1, c.sound.durationEstimate)),
        value: c.position < 0 ? "..." : Object.formatTime(c.position)
      })
    }
    c.sound.options.whileloading = function() {
      c.loaded = (c.sound.bytesLoaded / c.sound.bytesTotal)
      c.newEvent('loadedChanged', {
        pct: c.sound.bytesLoaded / c.sound.bytesTotal,
        value : c.sound.bytesLoaded,
        total : c.sound.bytesTotal
      })
    }
    c.sound.options.onload = function() {
      c.loaded = 1
      c.newEvent('loadedChanged', {
        pct: 1,
        value : c.sound.bytesLoaded,
        total : c.sound.bytesTotal
      })
    }
    c.sound.options.onid3 = function(){
      var elems = [c.sound.id3.artist, c.sound.id3.songname]
      c.newEvent('songChanged', {value: elems.join(" - ")})
    }
    if (c.playing) c.play()
  }

  c.playButton = Desk.Button('Play', c.pause.bind(c), {
    downTitle : 'Pause'
  })
  c.prevButton = Desk.Button('Previous', c.previous.bind(c))
  c.nextButton = Desk.Button('Next', c.next.bind(c))
  c.shuffleButton = Desk.Button('Shuffle', c.shuffle.bind(c))
  if (c.shuffling) c.shuffleButton.toggle()
  c.repeatButton = Desk.Button('Repeat', c.repeat.bind(c))
  if (c.repeating) c.repeatButton.toggle()
  c.volumeUpButton = Desk.Button('VolumeUp', c.volumeUp.bind(c))
  c.volumeDownButton = Desk.Button('VolumeDown', c.volumeDown.bind(c))
  c.playlistButton = Desk.Button('Playlist', c.togglePlaylist.bind(c))

  c.volumeElem = E('span', c.volume.toString(), null, 'Volume')
  
  c.appendChild(c.prevButton)
  c.appendChild(c.playButton)
  c.appendChild(c.nextButton)
  c.appendChild(c.shuffleButton)
  c.appendChild(c.repeatButton)
  c.appendChild(c.playlistButton)
  c.appendChild(c.volumeDownButton)
  c.appendChild(c.volumeUpButton)
  c.appendChild(c.volumeElem)


  c.seekElem = Desk.Slider(function(val) { c.seekToPct(val) })
  c.appendChild(c.seekElem)

  c.infoElem = E('div', null, null, 'SongInfo')
  c.appendChild(c.infoElem)
  
  c.indexElem = E('span', null, null, 'CurrentIndex')
  c.infoElem.appendChild(c.indexElem)
  c.sepElem = E('span', null, null, 'IndexSeparator')
  c.infoElem.appendChild(c.sepElem)
  c.allElem = E('span', null, null, 'PlaylistLength')
  c.infoElem.appendChild(c.allElem)

  c.currentSeekElem = E('span', null, null, 'CurrentSeek')
  c.infoElem.appendChild(c.currentSeekElem)
  
  c.currentlyPlaying = E('span', null, null, 'CurrentlyPlaying')
  c.infoElem.appendChild(c.currentlyPlaying)

  c.addListener('positionChanged', function(e) {
    if (e.pct != undefined) c.seekElem.setPosition(e.pct, false)
    c.currentSeekElem.innerHTML = e.value
  })
  c.addListener('loadedChanged', function(e) {
    if (e.pct != undefined) c.seekElem.setLoaded(e.pct)
  })
  c.addListener('songChanged', function(e){
    var plen = c.playlist.length
    c.indexElem.innerHTML = Math.min(plen, (c.currentIndex+1))
    c.allElem.innerHTML = plen
    c.currentlyPlaying.innerHTML = e.value
  })
  c.addListener('playlistChanged', function(e) {
    var plen = c.playlist.length
    c.indexElem.innerHTML = Math.min(plen, (c.currentIndex+1))
    c.allElem.innerHTML = plen
  })
  c.addListener('volumeChanged', function(e) {
    c.volumeElem.innerHTML = e.value
  })
  
  Desk.Droppable.makeDroppable(c)
  c.drop = function(dragged, e) {
    if (dragged.className.match(/\bwindowTaskbarEntry\b/)) {
      var w = dragged.window
      if (w.src && w.src.split(".").last().match(/mp3\/json$/i)) {
        this.addToPlaylist(w.src.replace(/items/,'files').replace(/\/json$/, ''))
        this.goToIndex(this.playlist.length-1)
      }
    } else if (dragged.className.match(/\bwindowGroupTitle\b/)) {
      var t = this
      var pll = this.playlist.length
      dragged.windowGroup.each(function(w){
        if (w.src && w.src.split(".").last().match(/mp3\/json$/i))
          t.addToPlaylist(w.src.replace(/items/,'files').replace(/\/json$/, ''))
      })
      if (pll != this.playlist.length)
        this.goToIndex(pll)
    }
  }
  c.dumpSession = function(){
    return {
      loader: 'Applets.MusicPlayer',
      data: {
        currentIndex : this.currentIndex,
        repeating : this.repeating,
        shuffling : this.shuffling,
        playing : this.playing,
        paused : this.paused,
        volume : this.volume,
        playlist : this.playlist,
        seek : (this.sound && this.sound.position)
      }
    }
  }
  c.menu = new Desk.Menu()
  c.menu.addTitle('Music player')
  c.menu.addItem('Play', c.play.bind(c))
  c.menu.addItem('Pause', c.pause.bind(c))
  c.menu.addItem('Stop', c.stop.bind(c))
  c.menu.addItem('Previous', c.previous.bind(c))
  c.menu.addItem('Next', c.next.bind(c))
  c.menu.addSeparator()
  c.menu.addItem('Repeat Song', c.repeat.bind(c))
  if (c.repeating) c.menu.checkItem('Repeat Song')
  else c.menu.uncheckItem('Repeat Song')
  c.menu.addItem('Shuffle', c.shuffle.bind(c))
  if (c.shuffling) c.menu.checkItem('Shuffle')
  else c.menu.uncheckItem('Shuffle')
  c.menu.addSeparator()
  c.menu.addItem('Clear playlist')
  Applets.bakeAppletMenu(c)
  
  c.newEvent('songChanged', {value: ''})

  return c
}
Applets.MusicPlayer.loadSession = function(data) {
  var mp = Applets.MusicPlayer()
  mp.playlist = data.playlist || []
  mp.setShuffling(data.shuffling)
  mp.setRepeating(data.repeating)
  mp.setVolume(data.volume)
  mp.playing = false
  mp.savedSeek = data.seek || 0
  mp.goToIndex(data.currentIndex, false)
  return mp
}
