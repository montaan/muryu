
Tr.addTranslations('en-US', {
  'Muryu.groups' : 'groups',
  'Muryu.folders' : 'folders',
  'Muryu.types' : 'types'
})
Tr.addTranslations('fi-FI', {
  'Workspace' : 'Työtila',
  'Add search' : 'Lisää haku',
  'Windows' : 'Ikkunat',
  'Collapse all groups' : 'Piilota kaikki ryhmät',
  'Expand all groups' : 'Laajenna kaikki ryhmät',
  'Utilities' : 'Työkalut',
  'Make note' : 'Tee muistiinpano',
  'Session' : 'Istunto',
  'Save Session' : 'Tallenna istunto',
  'Clear Session' : 'Nollaa asetukset',
  'Note' : 'Muistiinpano ',
  'help.html' : 'help.html',
  'help' : 'Apua',
  'Muryu.groups' : 'ryhmät',
  'Muryu.folders' : 'kansiot',
  'Muryu.types' : 'tiedostotyypit'
})
Tr.addTranslations('en-US', {
  'Note' : 'Note '
})
Tr.addTranslations('ja-JP', {
  'Date' : function(d){
    weekdays = ['日', '月', '火', '水', '木', '金', '土']
    months = ['一', '二', '三', '四', '五', '六', '七', '八', '九', '十', '十一', '十二']
    return ((d.getYear() + 1900) + '年' +
            (d.getMonth() + 1) + '月' +
            d.getDate() + '日' +
            ' ('+ weekdays[d.getDay()] + ') ' +
            d.getHours().toString().rjust(2, '0') + ':' +
            d.getMinutes().toString().rjust(2, '0') + ':' +
            d.getSeconds().toString().rjust(2, '0'))
  },
  'Workspace' : '作業領域',
  'Add search' : '検索を追加する',
  'Windows' : '窓',
  'Collapse all groups' : '全グループを隠す',
  'Expand all groups' : '全グループを広げる',
  'Utilities' : '道具',
  'Make note' : '覚書',
  'Session' : 'セッション',
  'Save Session' : 'セッションを保管する',
  'Clear Session' : 'セッションを消す',
  'Note' : '覚書 ',
  'help.html' : 'help.html',
  'help' : '使用法'
})
Tr.translations['fi'] = Tr.translations['fi-FI']


String.prototype.unfilterJSON = function() {
  if (this.slice(0,8) == 'while(0)') {
    return this.slice(9,-1)
  } else {
    return this
  }
}



Session.storage = {
  load : function(callback) {
    var t = this
    new Ajax.Request('/users/json', {
      method : 'get',
      asynchronous : false,
      onSuccess : function(res) {
        t.info = res.responseText.evalJSON()
        callback()
      }
    })
  },

  getItem : function(name) {
    var item = undefined
    try { item = this.info.preferences[name] } catch(e) {}
    return (item ? {key: name, value: item} : undefined)
  },

  setItem : function(name, value) {
    var params = {}
    params[name] = value
    new Ajax.Request('/users/set_preferences', { asynchronous : false, parameters : params })
  },

  removeItem : function(name) {
    var params = {}
    params[name] = true
    new Ajax.Request('/users/delete_preferences', { asynchronous : false, parameters : params })
  }
}




Muryu = {
  login : function() {
    var loggedIn = (Session.storage.info.name && Session.storage.info.name != 'anonymous')
    if (loggedIn) {
      if (Session.storage.info.preferences.language)
        Tr.language = Session.storage.info.preferences.language
      Ajax.Request.prototype.initialize = function(url, options) {
        this.transport = Ajax.getTransport()
        if (!options.method || options.method.toLowerCase() == 'post') {
          var secret = {secret : Session.storage.info.secret}
          if (options.parameters) {
            if (typeof options.parameters == 'object') {
              Object.extend(options.parameters, secret)
            } else {
              options.parameters = options.parameters.toString()+"&secret="+secret.secret
            }
          } else {
            options.parameters = secret
          }
        }
        this.setOptions(options)
        this.request(url)
      }
    }
    this.loggedIn = loggedIn
    return this.loggedIn
  },



  init : function(){
    try {
      var loggedIn = this.login()
      document.body.style.overflow = 'hidden'
      var container = E('div')
      container.style.position = 'absolute'
      var debug = false
      if (debug) {
        container.style.top = '200px'
        container.style.left = '200px'
        container.width = 256
        container.height = 256
        container.style.width = container.width + 'px'
        container.style.height = container.height + 'px'
        var c = E('div',null,null,null, container.style)
        c.style.border = '1px solid red'
        c.style.top = '-1'
        c.style.left = '-1'
        c.style.zIndex = 1000
        container.appendChild(c)
      } else {
        container.style.left = '0px'
        container.style.top = '0px'
        container.style.width = '100%'
        container.style.height = '100%'
        container.width = document.body.clientWidth
        container.height = document.body.clientHeight
      }
      document.body.appendChild(container)
      Desk.Windows.setContainer(container)

      var qvars = document.location.search.slice(1).split("&")
      var query = {}
      qvars.each(function(q){ var p = q.split("="); query[p[0]] = p[1] })
      var prefs = Session.storage.info.preferences
      if (prefs && prefs.addons && prefs.addons.length > 0 && (query.disable_addons == undefined)) {
        var addons = prefs.addons.split(";")
        for(var i=0; i<addons.length; i++) {
          Object.require(addons[i])
        }
      }
      $('while_loading').hide()
      document.body.style.backgroundColor = '#53565C'
      if (!Session.load())
        this.initView()
    } catch(e) {
      var wl = $('while_loading')
      wl.style.position = 'fixed'
      wl.style.backgroundColor = 'white'
      wl.style.color = 'black'
      wl.style.zIndex = 1000
      var hide = A("javascript:void($('while_loading').hide())", 'hide')
      hide.style.color = 'red'
      wl.append(
        E('h2', 'Error while loading'),
        Element.fromException(e),
        hide
      )
      wl.show()
      if (window.console && console.log)
        console.log(e)
      throw(e)
    }
  },

  initView : function() {
    RootWindow = new Desk.Window('app:Muryu.mapView', {
      group : 'root',
      movable : false,
      buttons : [],
      showInTaskbar : false,
      maximized : true,
      resizable : false,
      layer : -1
    })
    var topPanel = new Desk.Panel('left', {movable : false})
    topPanel.addApplet(Applets.Session())
    if (this.loggedIn) {
      topPanel.addApplet(Applets.MusicPlayer())
      topPanel.addApplet(Applets.Sets())
      topPanel.addApplet(Applets.Groups())
    }
    topPanel.addApplet(Applets.Taskbar())
  },

  mapView : function(win) {
    var rootMap = E('div')
    rootMap.style.width = '100%'
    rootMap.style.height = '100%'
    rootMap.style.overflow = 'hidden'
    rootMap.style.position = 'absolute'
    rootMap.dumpSession = function() {
      return win.map.dumpSession()
    }
    win.setTitle(null)
    win.setContent(rootMap)
    var topmap
    var q = ""
    if (this.loggedIn)
      q += "user:"+Session.storage.info.name
    else
      q += 'sort:date'
    if (win.contentDump) {
      var contentDump = Object.clone(win.contentDump)
      contentDump.data.container = rootMap
      contentDump.data.windowContainer = win.container
      topmap = Session.loadDump(contentDump)
      topmap.groupTree = topmap.children.find(function(c) { return c.isGroupTree })
      if (topmap.groupTree)
        topmap.groupTree.dumpVars.push('isGroupTree')
      topmap.setTree = topmap.children.find(function(c) { return c.isSetTree })
      if (topmap.setTree)
        topmap.setTree.dumpVars.push('isSetTree')
    } else {
      topmap = new View({
        container: rootMap,
        windowContainer: win.container
      })
      new TitledMap({
        parent : topmap,
        title : q,
        query : q,
        left: 30,
        top: 30
      })
      var typequeries = ['type:audio', 'type:video', 'type:html', 'type:pdf|postscript', 'type:text', 'type:application', 'type:image']
      topmap.typeTree = this.createQueryTree(topmap, Tr('Muryu.types'), typequeries, 290, 30, 'false')
    }
    Desk.Windows.rootWindow = win
    this.mainMap = topmap
    win.map = topmap
    win.addListener('resize', function(ev) {
      topmap.container.width = rootMap.offsetWidth
      topmap.container.height = rootMap.offsetHeight
      topmap.zoom(topmap.z, topmap.z, true)
    })
    win.addListener('containerChange', function(ev) {
      topmap.windowContainer = ev.value
      topmap.zoom(topmap.z, topmap.z, true)
    })



    topmap.updateGroupTree = function() {
      var groupqueries = Groups.map(function(s) { return 'group:"'+s.name+'"' })
      if (!topmap.groupTree) {
        topmap.groupTree = Muryu.createQueryTree(topmap, Tr('Muryu.groups'), groupqueries, 450,230)
        topmap.groupTree.isGroupTree = true
        topmap.groupTree.dumpVars.push('isGroupTree')
      } else {
        var old_queries = topmap.groupTree.portal.children.findAll(function(c){
          return c.map && groupqueries.include(c.map.query)
        }).pluck('map').pluck('query')
        var new_queries = Array.prototype.without.apply(groupqueries, old_queries)
        var b = topmap.groupTree.portal.ownHeight + 10
        Muryu.createQueryTree(topmap.groupTree.portal, null, new_queries, 0, b, true)
      }
    }
    topmap.updateSetTree = function() {
      var setqueries = Sets.map(function(s) { return 'set:"'+s.name+'"' })
      if (!topmap.setTree) {
        topmap.setTree = Muryu.createQueryTree(topmap, Tr('Muryu.folders'), setqueries, 450,30)
        topmap.setTree.isSetTree = true
        topmap.setTree.dumpVars.push('isSetTree')
      } else {
        var old_queries = topmap.setTree.portal.children.findAll(function(c){
          return c.map && setqueries.include(c.map.query)
        }).pluck('map').pluck('query')
        var new_queries = Array.prototype.without.apply(setqueries, old_queries)
        var b = topmap.setTree.portal.ownHeight + 10
        Muryu.createQueryTree(topmap.setTree.portal, null, new_queries, 0, b, true)
      }
    }
    Groups.addListener('update', topmap.updateGroupTree)
    Sets.addListener('update', topmap.updateSetTree)

    var menu = new Desk.Menu()
    menu.addTitle(Tr('Workspace'))
    menu.addItem(Tr('Add search'), function() {
      var ns = new TitledMap({
        query: q,
        parent: topmap,
        bgcolor: topmap.bgcolor,
        left: Math.pow(2,-topmap.targetZ)*(topmap.pointerX-topmap.x),
        top: Math.pow(2,-topmap.targetZ)*(topmap.pointerY-topmap.y)
      })
    })
/*    menu.addTitle(Tr('Utilities'))
    menu.addItem(Tr('Make note'), function(){ new Desk.Window('app:Notes.make') })*/
    menu.addTitle(Tr('Windows'))
    menu.addItem(Tr('Collapse all groups'), function() {
      Desk.Windows.taskbar.setCollapsedForAll(true)
    }, 'icons/CollapseAllGroups.png')
    menu.addItem(Tr('Expand all groups'), function() {
      Desk.Windows.taskbar.setCollapsedForAll(false)
    }, 'icons/ExpandAllGroups.png')
    if (this.loggedIn) {
      menu.addTitle(Tr('Session'))
      menu.addItem(Tr('Applets.Session.clear'), Session.clear.bind(Session))
      menu.addItem(Tr('Applets.Session.LogOut'), function(){ location.href = '/users/logout' })
    }
    menu.bind(rootMap)
  },

  createQueryTree : function(parent, title, queries, x, y, color) {
    if (!title) {
      var maptree = parent
      var map_parent = parent
    } else {
      var maptree = new TitledPortal({
        title : title,
        parent : parent,
        left : x,
        top : y,
        relativeZ : -1,
      })
      var map_parent = maptree.portal
    }
    for (var i=0; i<queries.length; i++) {
      new TitledMap({
        title : queries[i],
        query : queries[i],
        color : color,
        parent : map_parent,
        left : (title ? 0 : x),
        top : (title ? 0 : y) + i*64,
        relativeZ : 0
      })
    }
    return maptree
  }
}

