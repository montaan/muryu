
Muryu = {
  init : function(e) {
    var cm = document.getElementById("contentAreaContextMenu")
    cm.addEventListener("popupshowing",Muryu.popup,true);
    var up = Muryu.uploads = document.createElement("div")
    up.style.position = 'fixed'
    up.style.left = '0px'
    up.style.top = '0px'
  },

  popup : function(e) {
    document.getElementById("muryu-image").hidden = (!gContextMenu.onImage)
    document.getElementById("muryu-link").hidden = (!gContextMenu.onLink)
  },
  
  uploadImage : function() {
    Muryu.uploadURL(gContextMenu.imageURL)
  },
  uploadLink : function() {
    Muryu.uploadURL(gContextMenu.linkURL)
  },
  uploadPage : function() {
    Muryu.uploadURL(gBrowser.contentWindow.location)
  },
  
  uploadURL : function(url) {
    var w = gBrowser.contentWindow
    var upload_url = 'http://manifold.fhtr.org:8080/items/create'
    var query = 'json&url=' + encodeURIComponent(url) + '&referrer=' + encodeURIComponent(w.location)
    var d = document.createElement("div")
    d.style.borderRight = '1px solid black'
    d.style.fontFamily = 'Sans'
    d.style.backgroundColor = '#ffffdd'
    d.style.color = 'black'
    d.style.fontWeight = "bold"
    d.style.display = 'block'
    var l = document.createElement("div")
    l.style.height = '18px'
    l.style.backgroundColor = 'red'
    l.style.display = 'block'
    l.style.width = '6px'
    d.appendChild(l)
    Muryu.uploads.appendChild(d)
    w.document.body.appendChild(Muryu.uploads)
    req = new XMLHttpRequest()
    req.onreadystatechange = function(ev){
      if (req.readyState == 4) {
        d.removeChild(l)
        if (req.status == 200) {
          d.appendChild(document.createTextNode( req.responseText ))
        } else {
          d.appendChild(document.createTextNode( "There was an error: "
            +req.statusText ))
        }
        setTimeout(function(){ d.parentNode.removeChild(d) }, 3000)
      }
    }
    req.open('POST', upload_url, true)
    req.send(query)
  }
}

window.addEventListener("load",Muryu.init,true)

