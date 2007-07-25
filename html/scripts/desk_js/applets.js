Tr.addTranslations('en-US', {
  'Applets.Applet' : 'Applet',
  'Applets.Collapsed' : 'Collapsed',
  'Applets.Remove' : 'Remove applet',
  'Applets.Session' : 'Session',
  'Applets.Session.save' : 'Save session now',
  'Applets.Session.autosave' : 'Autosave',
  'Applets.Session.clear' : 'Reset session',
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
  'Applets.MusicPlayer.Playlist' : 'Playlist',
  'Applets.Sets' : 'Folders',
  'Applets.Groups' : 'Groups',
  'Groups.Editing' : 'Editing group: ',
  'Sets.Editing' : 'Editing folder: ',
  'Applets.Tags' : 'Tags',
  'Button.RemoveFromPlaylist' : 'Remove from playlist',
  'Applets.MusicPlayer.Play' : 'Play',
  'Applets.MusicPlayer.Pause' : 'Pause',
  'Applets.MusicPlayer.Next' : 'Next',
  'Applets.MusicPlayer.Previous' : 'Previous',
  'Applets.MusicPlayer.Shuffle' : 'Shuffle',
  'Applets.MusicPlayer.ShuffleDown' : 'Shuffle',
  'Applets.MusicPlayer.Repeat' : 'Repeat current song',
  'Applets.MusicPlayer.RepeatDown' : 'Repeat current song',
  'Applets.MusicPlayer.Playlist' : 'Playlist',
  'Applets.MusicPlayer.VolumeUp' : 'Volume up',
  'Applets.MusicPlayer.VolumeDown' : 'Volume down',
  'Applets.MusicPlayer.Mute' : 'Mute',
  'Button.Play' : 'Play',
  'Button.Pause' : 'Pause',
  'Button.Next' : 'Next',
  'Button.Previous' : 'Previous',
  'Button.Shuffle' : 'Shuffle',
  'Button.ShuffleDown' : 'Shuffle',
  'Button.Repeat' : 'Repeat current song',
  'Button.RepeatDown' : 'Repeat current song',
  'Button.Playlist' : 'Playlist',
  'Button.VolumeUp' : 'Volume up',
  'Button.VolumeDown' : 'Volume down',
  'Button.Mute' : 'Mute'
  
})
Tr.addTranslations('fi-FI', {
  'Applets.Applet' : 'Sovelma',
  'Applets.Collapsed' : 'Piilotettu',
  'Applets.Remove' : 'Poista sovelma',
  'Applets.Session' : 'Istunto',
  'Applets.Session.save' : 'Tallenna istunto',
  'Applets.Session.autosave' : 'Automaattinen tallennus',
  'Applets.Session.clear' : 'Nollaa asetukset',
  'Applets.Session.Welcome' : function(name) { return 'Tervetuloa, '+name+'!' },
  'Applets.Session.LogOut' : 'Kirjaudu ulos',
  'Applets.Session.LogIn' : 'Kirjaudu sisään',
  'Applets.Session.Register' : 'Luo uusi tunnus',
  'Applets.Session.AccountName' : 'Tunnus',
  'Applets.Session.Password' : 'Salasana',
  'Applets.Session.Upload' : 'Tiedostot',
  'Applets.Session.UploadItems' : 'Tuo tiedostoja',
  'Applets.Session.FirefoxExtension' : 'Firefoxin lisäosa',
  'Applets.Session.Settings' : 'Asetukset',
  'Applets.Session.BackgroundColor' : 'Taustaväri',
  'Button.Applets.Session.ToggleColors' : 'Värien näyttö',
  'Applets.MusicPlayer' : 'Soitin',
  'Applets.MusicPlayer.Playlist' : 'Soittolista',
  'Applets.Sets' : 'Kansiot',
  'Applets.Groups' : 'Ryhmät',
  'Groups.Editing' : 'Muokkain ryhmälle: ',
  'Sets.Editing' : 'Muokkain kansiolle: ',
  'Applets.Tags' : 'Tagit'
})



Applets = {
  create: function(name) {
    var applet = E('span', null,null, 'taskbarApplet '+name)
    applet.dumpSession = function(){
      return {loader: 'Applets', data: {name: name, collapsed: this.collapsed}}
    }
    var title = E('h4', Tr('Applets.'+name), null, 'windowGroupTitle')
    applet.titleElem = title
    applet.appendChild(applet.titleElem)
    applet.contentElem = E('div', null, null, 'taskbarAppletContent')
    applet.appendChild(applet.contentElem)
    Object.extend(applet, EventListener)
    applet.collapsed = false
    applet.setCollapsed = function(c) {
      this.collapsed = c
      if (applet.contentElem) {
        if (c)
          applet.contentElem.style.display = 'none'
        else
          applet.contentElem.style.display = 'inherit'
      }
      this.newEvent('collapseChange', { value: this.collapsed })
    }
    applet.toggleCollapsed = function(){ this.setCollapsed(!this.collapsed) }
    title.addEventListener('mousedown', function(ev){
      Event.stop(ev)
    }, false)
    title.addEventListener('dblclick', function(ev){
      if (Event.isLeftClick(ev)) {
        Event.stop(ev)
        applet.toggleCollapsed()
      }
    }, false)
    applet.menu = new Desk.Menu()
    applet.menu.addTitle(Tr('Applets.'+name))
    applet.menu.addItem(Tr('Applets.Collapsed'), function(){
      applet.toggleCollapsed()
    })
    applet.addListener('collapseChange', function(ev) {
      if (ev.value)
        applet.menu.checkItem(Tr('Applets.Collapsed'))
      else
        applet.menu.uncheckItem(Tr('Applets.Collapsed'))
    })
    applet.setCollapsed(false)
    applet.menu.addSeparator()
/*    applet.menu.addTitle(Tr('Applets.Applet'))
    applet.menu.addItem(Tr('Applets.Remove'), function(){
      applet.panel.removeApplet(applet)
    }, 'icons/Remove.png')*/
    applet.menu.bind(applet)
    return applet
  },

  loadSession : function(data){
    var applet = this[data.name]()
    applet.setCollapsed(data.collapsed)
    return applet
  }
}


Applets.Session = function(wm) {
  if (!wm) wm = Desk.Windows
  var c = Applets.create('Session')
  var controls = E('div')

  var logout = E('p', A('/users/logout', Tr('Applets.Session.LogOut')))
  logout.onclick = function(){
    c.unloadSaveSession()
  }

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
  submit.value = Tr('Applets.Session.LogIn')
  submit.type = 'submit'
  loginform.appendChild(submit)
  
  c.loggedIn = (Session.storage.info.name && Session.storage.info.name != 'anonymous')
  
  if (c.loggedIn) {
    controls.appendChild(E('p', Tr('Applets.Session.Welcome', Session.storage.info.name)))
    controls.appendChild(logout)
    controls.appendChild(E('h5', Tr('Applets.Session.Upload'), null, 'windowGroupTitle'))
    controls.appendChild(E('p', A('/items', Tr('Applets.Session.UploadItems'))))
    controls.appendChild(E('p', A('muryu_uploader.xpi', Tr('Applets.Session.FirefoxExtension'))))
    controls.appendChild(E('h5', Tr('Applets.Session.Settings'), null, 'windowGroupTitle'))
    var colorToggles = E('p', 'BG [ ')
    var colors = {
      flint: '13191C',
      blue: '03233C',
      purple: '231323'
    }
    for (var i in colors) {
      var a = A("javascript:void(document.focusedMap.root.setBgColor('"+colors[i]+"'))", i)
      colorToggles.appendChild(a)
      colorToggles.appendChild(T(' | '))
    }
    colorToggles.removeChild(colorToggles.lastChild)
    colorToggles.appendChild(T(' ]'))
    controls.appendChild(colorToggles)
    c.autosave = true
  } else {
    c.autosave = false
    $(c.titleElem).detachSelf()
    controls.appendChild(loginform)
    controls.appendChild(E('p', A('/users/register', Tr('Applets.Session.Register'))))
  }
  
  c.contentElem.appendChild(controls)

  c.session = null
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
  c.unloadSaveSession = function() {
    if (this.autosave) this.saveSession()
  }
  c.clearSession = function(){
    if (this.loggedIn) {
      this.sessionChanged = false
      Session.clear()
      this.loggedIn = false
      document.location.reload()
    }
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
  if (c.loggedIn) {
    c.autosaveInterval = setInterval(c.autosaveSession.bind(c), 5*60*1000) 
    window.addEventListener('unload', c.unloadSaveSession.bind(c), false)
    c.menu.addItem(Tr('Applets.Session.save'), c.saveSession.bind(c))
    c.menu.addItem(Tr('Applets.Session.autosave'), c.toggleAutosave.bind(c))
    c.menu.checkItem(Tr('Applets.Session.autosave'))
    c.menu.addSeparator()
    c.menu.addItem(Tr('Applets.Session.clear'), c.clearSession.bind(c))
    c.menu.addItem(Tr('Applets.Session.LogOut'), function(){
      c.unloadSaveSession()
      document.location.href = '/users/logout'
    })
  }

  return c
}


Applets.OpenURL = function(wm) {
  if (!wm) wm = Desk.Windows
  var c = Applets.create('OpenURL')
  var f = E('form', null,null, 'taskbarForm')
  var t = E('input',null,null,'taskbarTextInput',null,
    {type:'text'})
  var s = E('input',null,null,'taskbarSubmitInput',null,
    {type:'submit', value:'Open'})
  c.contentElem.appendChild(f)
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
  return c
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
  var c = Applets.create('MusicPlayer')
  MusicPlayer = c

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
    if (this.shuffling) this.menu.checkItem(Tr('Applets.MusicPlayer.Shuffle'))
    else this.menu.uncheckItem(Tr('Applets.MusicPlayer.Shuffle'))
  }
  
  c.repeat = function(){
    this.setRepeating(!this.repeating)
  }
  
  c.setRepeating = function(v) {
    if (v != this.repeating)
      this.repeatButton.toggle()
    this.repeating = v
    if (this.repeating) this.menu.checkItem(Tr('Applets.MusicPlayer.RepeatSong'))
    else this.menu.uncheckItem(Tr('Applets.MusicPlayer.RepeatSong'))
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
    tlc.style.width = '100%'
    tlc.style.height = '100%'
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
    }, { showText: true, textSide : 'right' }))

    var plc = E('div', null, 'MusicPlayer_playlistContainer')
    plc.style.overflow = 'auto'
    pl.getIndex = function(obj) {
      var c = this.childNodes
      for (var i=0; i<c.length; i++) {
        if (c[i] == obj) return i
      }
      return 0
    }
    w.addListener('resize', function(){
      plc.style.height = (tlc.offsetHeight - plc.offsetTop + tlc.offsetTop) + 'px'
    })
    w.addListener('containerChange', function(){
      plc.style.height = (tlc.offsetHeight - plc.offsetTop + tlc.offsetTop) + 'px'
    })
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
      t.currentIndex = this.getIndex(this.current)
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

  c.init = function() {
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
  if (soundManager.enabled)
    c.init()
  else
    soundManager.onload = c.init

  c.playButton = Desk.Button('Play', c.pause.bind(c), {
    downTitle : 'Pause'
  })
  c.prevButton = Desk.Button('Previous', c.previous.bind(c))
  c.nextButton = Desk.Button('Next', c.next.bind(c))
  c.shuffleButton = Desk.Button('Shuffle', c.shuffle.bind(c), {downTitle: 'ShuffleDown'})
  if (c.shuffling) c.shuffleButton.toggle()
  c.repeatButton = Desk.Button('Repeat', c.repeat.bind(c), {downTitle: 'RepeatDown'})
  if (c.repeating) c.repeatButton.toggle()
  c.volumeUpButton = Desk.Button('VolumeUp', c.volumeUp.bind(c))
  c.volumeDownButton = Desk.Button('VolumeDown', c.volumeDown.bind(c))
  c.playlistButton = Desk.Button('Playlist', c.togglePlaylist.bind(c))

  c.volumeElem = E('span', c.volume.toString(), null, 'Volume')
  
  c.contentElem.appendChild(c.prevButton)
  c.contentElem.appendChild(c.playButton)
  c.contentElem.appendChild(c.nextButton)
  c.contentElem.appendChild(c.shuffleButton)
  c.contentElem.appendChild(c.repeatButton)
  c.contentElem.appendChild(c.playlistButton)
  c.contentElem.appendChild(c.volumeDownButton)
  c.contentElem.appendChild(c.volumeUpButton)
  c.contentElem.appendChild(c.volumeElem)


  c.seekElem = Desk.Slider(function(val) { c.seekToPct(val) })
  c.contentElem.appendChild(c.seekElem)

  c.infoElem = E('div', null, null, 'SongInfo')
  c.contentElem.appendChild(c.infoElem)
  
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
  c.menu.addItem(Tr('Applets.MusicPlayer.Play'), c.play.bind(c))
  c.menu.addItem(Tr('Applets.MusicPlayer.Pause'), c.pause.bind(c))
  c.menu.addItem(Tr('Applets.MusicPlayer.Previous'), c.previous.bind(c))
  c.menu.addItem(Tr('Applets.MusicPlayer.Next'), c.next.bind(c))
  c.menu.addSeparator()
  c.menu.addItem(Tr('Applets.MusicPlayer.Repeat'), c.repeat.bind(c))
  if (c.repeating) c.menu.checkItem(Tr('Applets.MusicPlayer.Repeat'))
  else c.menu.uncheckItem(Tr('Applets.MusicPlayer.Repeat'))
  c.menu.addItem(Tr('Applets.MusicPlayer.Shuffle'), c.shuffle.bind(c))
  if (c.shuffling) c.menu.checkItem(Tr('Applets.MusicPlayer.Shuffle'))
  else c.menu.uncheckItem(Tr('Applets.MusicPlayer.Shuffle'))
  c.menu.addSeparator()
  c.menu.addItem(Tr('Applets.MusicPlayer.VolumeUp'), c.volumeUp.bind(c))
  c.menu.addItem(Tr('Applets.MusicPlayer.VolumeDown'), c.volumeDown.bind(c))

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



Users = []
Object.extend(Users, EventListener)
Object.extend(Users, {

  init : function() {
    Groups.addListener('update', this.update.bind(this))
    this.update()
  },

  update : function() {
    this.clear()
    for (var i=0; i<Groups.length; i++) {
      this.add(Groups[i].owner)
      for (var j=0; j<Groups[i].members.length; j++) {
        this.add(Groups[i].members[j])
      }
    }
    this.sort()
    this.newEvent('update')
  },
  
  add : function(n) {
    if (!this.include(n))
      this.push(n)
  }

})
Session.addListener('init', Users.init.bind(Users))


Sets = []
Object.extend(Sets, EventListener)
Object.extend(Sets, {
  
  init : function() {
    this.editors = []
    this.update()
    Groups.addListener('update', this.updateEditors.bind(this))
    Users.addListener('update', this.updateEditors.bind(this))
  },

  update : function() {
    new Ajax.Request('/sets/json', {
      method : 'get',
      onSuccess: function(res){
        var items = res.responseText.evalJSON()
        this.clear()
        for (var i=0; i<items.length; i++)
          this.push(items[i])
        this.newEvent('update', {value:items})
      }.bind(this)
    })
  },
  
  updateEditors : function(){
    for (var i=0; i<this.editors.length; i++)
      this.updateAccessList(this.editors[i])
  },
  
  updateAccessList : function(accessList){
    var list = []
    list.push({title:'Users'})
    list = list.concat( Users.map(
      function(g){ 
        return {value: 'users/'+g, title:g, disabled:(g == accessList.owner)}
      }) 
    )
    list.push({title:'Groups'})
    list = list.concat( Groups.map(
      function(g){
        if (g.namespace == 'users') return null
        return {value:g.namespace+'/'+g.name, title:g.name + ' ('+g.owner+')'}
      }).compact()
    )
    var accessEditor = Editors.listOrNew('groups', accessList.groups, [
      list,
      true
    ])
    if (accessList.firstChild)
      $(accessList.firstChild).detachSelf()
    accessList.append(accessEditor)
  },
  
  editor : function(win) {
    var set = win.parameters
    win.setTitle(Tr('Sets.Editing', set.name + ' ('+ set.owner+')'))
    win.setContent('Loading...')
    win.setGroup(Tr('WindowGroup.editors'))
    new Ajax.Request('/sets/'+set.owner+'/'+set.name+'/json', {
      method: 'get',
      onSuccess : function(res) {
        var set_info = res.responseText.evalJSON()
        var editForm = E('form')
        editForm.action = '/sets/'+set.owner+'/'+set.name+'/edit'
        editForm.method = 'POST'
        editForm.addEventListener('submit', function(ev){
          Event.stop(ev)
          $(this).request({
            onSuccess : function(res){
              Sets.update()
              win.close()
            }
          })
        }, false)
        var nameEditor = E('input')
        nameEditor.type = 'text'
        nameEditor.name = 'name'
        nameEditor.value = set.name
        var submit = E('input', null, null, null, null, {type:'submit', value: Tr('Item.done')})
        var accessEditor = E('span')
        accessEditor.owner = set_info.owner
        accessEditor.groups = set_info.groups
        this.editors.push(accessEditor)
        this.updateAccessList(accessEditor)
        win.addListener('close', function(){this.editors.deleteFirst(accessEditor)}.bind(this))
        editForm.append(
          E('h5', Tr('Name')),
          nameEditor,
          E('h5', Tr('Access control')),
          accessEditor,
          submit
        )
        var div = E('div', null, null, 'editor')
        div.append(editForm)
        win.setContent(div)
      }.bind(this)
    })
  },
  
  viewer : function(win) {
    var set = win.parameters
    win.setTitle(Tr('Set ', set.name + ' ('+ set.owner+')'))
    win.setContent("I'd go to your Sets area into the subarea of this particular set right about now.")
  }
})
Session.addListener('init', Sets.init.bind(Sets))


Groups = []
Object.extend(Groups, EventListener)
Object.extend(Groups, {
  
  init : function() {
    this.editors = []
    this.update()
    Users.addListener('update', this.updateEditors.bind(this))
  },

  update : function() {
    new Ajax.Request('/groups/json', {
      method : 'get',
      onSuccess: function(res){
        var items = res.responseText.evalJSON()
        this.clear()
        for (var i=0; i<items.length; i++)
          this.push(items[i])
        this.newEvent('update', {value:items})
      }.bind(this)
    })
  },
  
  updateEditors : function(){
    for (var i=0; i<this.editors.length; i++)
      this.updateAccessList(this.editors[i])
  },
  
  updateAccessList : function(accessList){
    var accessEditor = Editors.listOrNew('users', accessList.members, [
      [{title:'Users'}].concat( Users.map(function(u){
        var d = {value:u, title:u}
        if (u == accessList.owner)
          d.disabled = true
        return d
      }) ),
      true
    ])
    if (accessList.firstChild)
      $(accessList.firstChild).detachSelf()
    accessList.append(accessEditor)
  },
  
  editor : function(win) {
    var group = win.parameters
    win.setTitle(Tr('Groups.Editing', group.name + ' ('+ group.owner+')'))
    win.setContent('Loading...')
    win.setGroup(Tr('WindowGroup.editors'))
    new Ajax.Request('/groups/'+group.name+'/json', {
      method: 'get',
      onSuccess : function(res) {
        var group_info = res.responseText.evalJSON()
        var editForm = E('form')
        editForm.action = '/groups/'+group.name+'/edit'
        editForm.method = 'POST'
        editForm.addEventListener('submit', function(ev){
          Event.stop(ev)
          $(this).request({
            onSuccess : function(res){
              Groups.update()
              win.close()
            }
          })
        }, false)
        var nameEditor = E('input')
        nameEditor.type = 'text'
        nameEditor.name = 'name'
        nameEditor.value = group_info.name
        var accessEditor = E('span')
        accessEditor.members = group_info.members
        accessEditor.owner = group_info.owner
        this.editors.push(accessEditor)
        this.updateAccessList(accessEditor)
        win.addListener('close', function(){this.editors.deleteFirst(accessEditor)}.bind(this))
        var submit = E('input', null, null, null, null, {type:'submit', value: Tr('Item.done')})
        editForm.append(
          E('h5', Tr('Name')),
          nameEditor,
          E('h5', Tr('Access control')),
          accessEditor,
          submit
        )
        var div = E('div', null, null, 'editor')
        div.append(editForm)
        win.setContent(div)
      }.bind(this)
    })
  },
  
  viewer : function(win) {
    var group = win.parameters
    win.setTitle(Tr('Group ', group.name + ' ('+ group.owner+')'))
    win.setContent("I'd go to your Groups area into the subarea of this particular group right about now.")
  }
})
Session.addListener('init', Groups.init.bind(Groups))



Applets.Groups = function(wm) {
 if (!wm) wm = Desk.Windows
  var c = Applets.create('Groups')
  var d = E('ul', null, null, 'setList')
  c.contentElem.appendChild(d)
  c.update = function(){
    while (d.firstChild) d.removeChild(d.firstChild)
    Groups.each(function(it){
      var li = E('li')
      var key = '/groups/'+it.name
      var itemLink = A(key, it.name)
      itemLink.onclick = function(ev) {
        if (Event.isLeftClick(ev)) {
          Event.stop(ev)
          new Desk.Window('app:Groups.viewer', {parameters : it})
        }
      }
      var userLink = A('/users/'+it.owner, it.owner)
      li.append(
        itemLink,' ( ', userLink
      )
      if (it.writable) {
        var editLink = A(key, 'edit')
        editLink.onclick = function(ev) {
          if (Event.isLeftClick(ev)) {
            Event.stop(ev)
            new Desk.Window('app:Groups.editor', {parameters : it})
          }
        }
        li.append(
          ' - ', editLink
        )
      }
      li.append(' )')
      it.members.each(function(m){
        var userLink = A('/users/'+m, m)
        var p = E('p', null, null, null, {marginLeft: '10px'})
        p.append('- ', userLink)
        li.append(p)
      })
      d.appendChild(li)
    })
  }
  Groups.addListener('update', c.update.bind(c))
  c.update()
  return c
}


Applets.Sets = function(wm) {
 if (!wm) wm = Desk.Windows
  var c = Applets.create('Sets')
  var d = E('ul', null, null, 'setList')
  c.contentElem.appendChild(d)
  c.update = function(){
    while (d.firstChild) d.removeChild(d.firstChild)
    Sets.each(function(it){
      var li = E('li')
      var key = '/sets/'+it.namespace+'/'+it.name
      var itemLink = A(key, it.name)
      itemLink.onclick = function(ev) {
        if (Event.isLeftClick(ev)) {
          Event.stop(ev)
          new Desk.Window('app:Sets.viewer', {parameters : it})
        }
      }
      var userLink = A('/users/'+it.owner, it.owner)
      li.append(
        itemLink,' ( ', userLink
      )
      if (it.writable) {
        var editLink = A(key, 'edit')
        editLink.onclick = function(ev) {
          if (Event.isLeftClick(ev)) {
            Event.stop(ev)
            new Desk.Window('app:Sets.editor', {parameters : it})
          }
        }
        li.append(
          ' - ', editLink
        )
      }
      li.append(' )')
      d.appendChild(li)
    })
  }
  Sets.addListener('update', c.update.bind(c))
  c.update()
  return c
}

Applets.SelectionEditor = function(wm) {
}



Notes = {
  make : function(win) {
    var ta = E('textarea')
    ta.style.display = 'block'
    ta.style.width = '100%'
    ta.style.height = '200px'
    ta.style.backgroundColor = '#DDD'
    ta.style.border = '0px'
    ta.style.padding = '2px'
    ta.style.color = '#000'
    ta.style.fontSize = '14px'
    ta.style.fontWeight = 'normal'
    ta.style.fontFamily = 'Serif'
    if (win.title == win.src)
      win.setTitle(Tr('Note', Tr('Date', new Date())))
    win.addListener('resize', function() {
      ta.style.width = parseInt(win.contentElement.style.width) - 6 + 'px'
      ta.style.height = parseInt(win.contentElement.style.height) - 7 + 'px'
    })
    if (win.parameters)
      ta.value = win.parameters.content
    else
      win.parameters = {content:''}
    ta.ival = setInterval(function() {
      if (win.parameters.content != ta.value)
        win.parameters.content = ta.value
    }, 1000)
    win.addListener('close', function() { clearInterval(ta.ival) })
    win.setContent(ta)
  }
}

