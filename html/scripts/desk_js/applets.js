Tr.addTranslations('en-US', {
  'Applets.Applet' : 'Applet',
  'Applets.Remove' : 'Remove applet',
  'Applets.Session' : 'Session',
  'Applets.Session.save' : 'Save session now',
  'Applets.Session.autosave' : 'Autosave',
  'Applets.Session.clear' : 'Clear session',
  'Applets.MusicPlayer' : 'Player',
})
Tr.addTranslations('fi-FI', {
  'Applets.Applet' : 'Sovelma',
  'Applets.Remove' : 'Poista sovelma',
  'Applets.Session' : 'Istunto',
  'Applets.Session.save' : 'Tallenna istunto',
  'Applets.Session.autosave' : 'Automaattinen tallennus',
  'Applets.Session.clear' : 'Pyyhi istunto',
  'Applets.MusicPlayer' : 'Soitin',
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
  c.appendChild(title)
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
    if (this.autosave)
      this.saveSession()
  }
  c.saveSession = function(){
      Session.save()
  }
  c.clearSession = function(){
    Session.clear()
  }
  c.dumpSession = function(){
    return {loader: 'Applets.Session', data: ''}
  }

  wm.addListener('addWindow', function(e){
    if (e.value.avoid) {
      e.addListener('addApplet', c.autosaveSession)
      e.addListener('removeApplet', c.autosaveSession)
    }
    c.autosaveSession()
  })
  wm.addListener('removeWindow', function(e){
    if (e.value.avoid) {
      e.removeListener('addApplet', c.autosaveSession)
      e.removeListener('removeApplet', c.autosaveSession)
    }
    c.autosaveSession()
  })
  window.addEventListener('unload', c.saveSession, false)
  c.menu = new Desk.Menu()
  c.menu.addTitle(Tr('Applets.Session'))
  c.menu.addItem(Tr('Applets.Session.save'), c.saveSession)
  c.menu.addItem(Tr('Applets.Session.autosave'), function(){
    c.toggleAutosave()
  })
  c.menu.checkItem(Tr('Applets.Session.autosave'))
  c.menu.addSeparator()
  c.menu.addItem(Tr('Applets.Session.clear'), c.clearSession)
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
  var e = E('div', null, null, 'slider')
  e.knob = E('div', null, null, 'sliderKnob')
  e.onmousedown = function(ev) {
    var lx = ev.layerX
    if (ev.target == e.knob) lx += 1
    else lx -= 4
    e.setPosition(lx / e.offsetWidth)
  }
  e.appendChild(e.knob)
  Object.extend(e, EventListener)
  e.position = 0
  e.setPosition = function(val, sendEvent) {
    this.position = Math.min(Math.max(0, val), 1)
    e.knob.style.width = (val * (e.offsetWidth-2)) + 'px'
    if (sendEvent != false)
      this.newEvent('valueChanged', { value: val })
  }
  if (callback)
    e.addListener('valueChanged', function(e) { callback(e.value) })
  return e
}


MusicPlayer = null
Applets.MusicPlayer = function() {
  var c = E('span', null,null, 'taskbarApplet MusicPlayer')
  var title = E('h4', Tr('Applets.MusicPlayer'), null, 'windowGroupTitle')
//   c.appendChild(title)
  MusicPlayer = c

  Object.extend(c, EventListener)
  c.playlist = []
  c.currentIndex = 0
  c.savedSeek = 0
  c.volume = 100
  c.currentURL = null
  c.repeating = false
  c.shuffling = false
  c.soundID = 'currentMPSound'
  c.firstPlay = true

  c.addToPlaylist = function(item) {
    this.playlist.push(item)
    this.newEvent('playlistChanged', { value: this.playlist })
  }
  
  c.removeFromPlaylistAt = function(index) {
    this.playlist.splice(index, 1)
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
      this.playButton.style.display = 'none'
      this.pauseButton.style.display = null
      this.playing = true
      this.currentItem = this.playlist[this.currentIndex]
      if (this.currentItem) {
        this.currentURL = (typeof this.currentItem == 'string' ?
                           this.currentItem :
                           this.currentItem.src)
        var params = {url: this.currentURL, autoPlay: true, stream: true, volume: this.volume}
        soundManager.load(this.soundID, params)
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
      this.pauseButton.style.display = 'none'
      this.playButton.style.display = null
    } else {
      this.playButton.style.display = 'none'
      this.pauseButton.style.display = null
    }
  }
  
  c.seekTo = function(pos) {
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

  c.togglePlaylist = function() {
    new Desk.Window(E('div', this.playlist.join("<br/>")))
  }

  soundManager.onload = function() {
    soundManager.createSound(c.soundID, {url: 'data/null.mp3'})
    c.sound = soundManager.sounds[c.soundID]
    c.sound.setVolume(c.volume)
    c.sound.options.onfinish = c.playNext
    c.sound.options.onload = function(e) {
      c.seekTo(c.savedSeek)
      c.savedSeek = 0
      if (c.paused) soundManager.pause(c.soundID)
      c.updateButtons()
    }
    c.sound.options.whileplaying = function(e) {
      c.newEvent('positionChanged', {
        pct: (c.sound.position / c.sound.durationEstimate),
        value: Object.formatTime(c.sound.position)
      })
    }
    c.sound.options.onid3 = function(e){
      var elems = [c.sound.id3.artist, c.sound.id3.songname]
      c.newEvent('songChanged', {value: elems.join(" - ")})
    }
    if (c.playing) c.play()
  }

  c.playButton = Desk.Button('Play', c.pause.bind(c))
  c.pauseButton = Desk.Button('Pause', c.pause.bind(c))
  c.pauseButton.style.display = 'none'
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
  c.appendChild(c.pauseButton)
  c.appendChild(c.playButton)
  c.appendChild(c.nextButton)
  c.appendChild(c.shuffleButton)
  c.appendChild(c.repeatButton)
  c.appendChild(c.playlistButton)
  c.appendChild(c.volumeUpButton)
  c.appendChild(c.volumeDownButton)
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
  
  Droppable.makeDroppable(c)
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
