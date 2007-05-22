// Fancy form input creators for different data types.
Editors = {

  // Time picker
  time : function(name, value, args) {
    var cont = E('div', null, null, 'timeEditor')
    var nullVal = true
    if (!value) {
      value = new Date()
    } else {
      nullVal = false
    }
    var y = Editors.intInput('year', value.getYear()+1900)
    var m = Editors.limitedIntInput('month', value.getMonth()+1, [1, 12, 2])
    var d = Editors.limitedIntInput('day', value.getDate(), [1, 31, 2])
    d.validator = function(v){
      var ok = false
      try{ ok = (new Date([Math.abs(y.value%1000),m.value,v].join(' ')).getDate() == parseInt(v)) }
      catch(e) { ok = false}
      return ok
    }
    var h = Editors.limitedIntInput('hour', value.getHours(), [0, 23, 2])
    h.style.marginLeft = '10px'
    var min = Editors.limitedIntInput('minute', value.getMinutes(), [0, 59, 2])
    var s = Editors.limitedIntInput('second', value.getSeconds(), [0, 59, 2])
    var hid = Editors.hiddenInput(name)
    var tz = ({value: value.getTimezoneOffset() / 60})
    var updater = function(){
      hid.value = ([y.value, m.value, d.value].join("-") + ' ' +
                   [h.value, min.value, s.value].join(":") + ' ' +
                   (tz.value < 0 ? tz.value : '+'+tz.value))
    }
    if (nullVal) {
      hid.value = ''
    } else {
      updater()
    }
    var parts = [y,m,d,h,min,s]
    parts.each(function(f){
      f.addEventListener('change', updater, false)
      cont.appendChild(f)
    })
    cont.appendChild(hid)
    return cont
  },

  intInput : function(name, value) {
    var inp = E('input', null, null, 'intInput',
      {width: Math.max(value.toString().length, 2) * 0.75 + 'em'},
      {type:"text", size: value.toString().length, "name": name, "value": value})
    inp.addEventListener('change', function(e){
      if (inp.validator && !inp.validator(inp.value)) {
        inp.value = value
        e.preventDefault()
        e.stopPropagation()
        return
      }
      inp.value = parseInt(inp.value)
      if (isNaN(inp.value)) inp.value = value
    }, true)
    return inp
  },

  limitedIntInput : function(name, value, args) {
    var low = args[0]
    var high = args[1]
    var padding = args[2] || 0
    var inp = E('input', null, null, 'limitedIntInput',
      {width: Math.max(value.toString().length, 2) * 0.75 + 'em'},
      { type:"text", size: value.toString().length,
        "name": name, "value": value.toString().rjust(padding, '0'),
        "low": low, "high": high
      })
    inp.addEventListener('change', function(e){
      if (inp.validator && !inp.validator(inp.value)) {
        inp.value = value.toString().rjust(padding, '0')
        e.preventDefault()
        e.stopPropagation()
        return
      }
      var v = Math.max(inp.low, Math.min(inp.high, parseInt(inp.value)))
      if (isNaN(v)) v = value
      inp.value = v.toString().rjust(padding, '0')
    }, true)
    return inp
  },

  hiddenInput : function(name, value) {
    var inp = E('input', null, null, null, null,
      {type:"hidden", "name": name, "value": value})
    return inp
  },

  // Expanding textarea
  text : function(name, value) {
    var inp = E('textarea', value, null, 'textEditor', null,
      {name: name})
    return inp
  },

  // String
  string : function(name, value) {
    var inp = E('input', null, null, 'stringEditor', null,
      {type:"text", "name": name, "value": value})
    return inp
  },

  // One or several from a list of values
  list : function(name, value, args){
    var list_values = args[0]
    var pick_multiple = args[1]
    var list = E('div', null, null, 'listEditor')
    if (typeof value != 'object') value = [value]
    if (pick_multiple) {
      var ul = E('ul')
      list_values.each(function(lv){
        var d = E('li')
        var opt = E('input')
        opt.type = 'checkbox'
        opt.name = name
        opt.value = lv
        if (value) opt.checked = value.include(lv)
        d.appendChild(opt)
        d.appendChild(T(lv))
        ul.appendChild(d)
      })
      list.appendChild(ul)
    } else {
      var inp = E('select', null, null, null, null, {name: name})
      list_values.each(function(lv){
        var opt = E('option', lv)
        opt.value = lv
        if (value) opt.selected = value.include(lv)
        inp.appendChild(opt)
      })
      list.appendChild(inp)
    }
    return list
  },

  // One or several from a list of values or a new value
  listOrNew : function(name, value, args) {
    var ls = Editors.list(name, value, args)
    ls.appendChild(E('p','+ ',null,'listOrNewSeparator'))
    ls.appendChild(Editors.string(name+'.new', ''))
    return ls
  },

  // Autocompleting text field
  autoComplete : function(name, value, complete_values) {
    var inp = E('input', null, null, 'autoCompleteEditor', null,
      {type:"text", "name": name, "value": value})
    return inp
  },

  // Map coordinates
  location : function(name, value) {
    var loc = E('div', null, null, 'locationEditor')
    var hid = E('input', null, null, null, null,
      {type:"hidden", "name": name, "value": value})
    loc.appendChild(hid)
    if (typeof GBrowserIsCompatible != 'undefined' && GBrowserIsCompatible()) {
      var txt = E('span', value)
      loc.appendChild(txt)
      var latlng = [ NaN ]
      if (value) {
        latlng = value.replace(/[)(]/g, '').split(",").map(parseFloat)
      }
      if (isNaN(latlng[0]) || isNaN(latlng[1])) latlng = [0.0, 0.0]
      loc.mapAttachNode = document.body
      var loaded = function() {
        var map_outer_cont = E('span', null, null, 'google_map',
          {display: 'block', position: 'absolute'})
        if (loc.mapLeft) map_outer_cont.style.left = loc.mapLeft
        if (loc.mapTop) map_outer_cont.style.top = loc.mapTop
        loc.mapAttachNode.appendChild(map_outer_cont)
        var map_cont = E('span', null, null, null,
          {width: '100%', height: '100%', display: 'block'})
        map_outer_cont.appendChild(map_cont)
        var map = new GMap2(map_cont)
        map.setCenter(new GLatLng(latlng[0], latlng[1]), 3)
        var marker = new GMarker(new GLatLng(latlng[0], latlng[1]), {draggable: true})
        map.addOverlay(marker)
        map.addControl(new GSmallZoomControl())
        map.addControl(new GMapTypeControl())
        map.enableContinuousZoom()
        map.enableScrollWheelZoom()
        var updateVal = function(pt) {
          hid.value = pt.toUrlValue()
          txt.innerHTML = '(' + pt.toUrlValue() + ')'
        }
        GEvent.addListener(map, 'click', function(ol, pt){
          if (!ol) marker.setPoint(pt)
          updateVal(marker.getPoint())
        })
        GEvent.addListener(marker, 'dragend', function(){
          updateVal(marker.getPoint())
        })
        map_cont.addEventListener("DOMMouseScroll", function(ev){
          ev.stopPropagation()
          ev.preventDefault()
        }, false)
        map_outer_cont.unloadMonitor = setInterval(function(){
          var o = loc
          while (o) {
            if (o == document.body) return
            o = o.parentNode
          }
          clearInterval(map_outer_cont.unloadMonitor)
          $(map_outer_cont).detachSelf()
          GUnload()
        },100)
      }
      loc.loadMonitor = setInterval(function(){
        var o = loc
        while (o) {
          if (o == document.body) {
            clearInterval(loc.loadMonitor)
            loaded()
            return
          }
          o = o.parentNode
        }
      },100)
    } else {
      hid.type = 'text'
    }
    return loc
  },

  // Valid URL
  url : function(name, value) {
    var inp = E('input', null, null, 'urlEditor', null,
      {type:"text", "name": name, "value": value})
    return inp
  }
}
