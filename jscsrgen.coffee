$ () ->
  # dom
  form        = $ '#formCSR'
  txtStatus   = $ '#status'
  btnGenerate = $ '#btnGenerate'
  btnDownload = $ '#btnDownload'

  contentCSR  = $ '#contentCSR'

  input       = $ ".form-control", form

  # tempStorage
  pem         = {}

  # check webworker and html5 file
  runnable = typeof(Worker) isnt undefined and Blob isnt undefined
  if runnable
    txtStatus
    .attr 'class', 'alert alert-info'
    .html '<p>Ready to generate your CSR.</p>'
  else
    txtStatus
    .attr 'class', 'alert alert-danger'
    .html '<p>Missing support of <strong>WebWorker</strong> or <strong>Blob</strong>, unable to generate CSR.</p>'

    input.attr "disabled", false
    btnGenerate.attr 'disabled', true
    return

  # country selector
  formatCountry = (country) ->
    return country.text unless country.id
    "<strong class=\"monospace\">#{country.id}</strong> " + country.text

  $("#countryName").select2
    formatResult:    formatCountry
    formatSelection: formatCountry
    esacpeMarkup   : (m) -> m

  # santize common file
  sanitizeCommonName = (cn) ->
    cn
    .replace /^http:\/\//, ''
    .replace /^https:\/\//, ''
    .replace /\./g, '_'
    .replace /^\*/, 'star'
    .replace /[^a-zA-Z0-9_\-]+/g, ''

  # download csr as zip
  downloadCSRBundle = () ->
    cn  = sanitizeCommonName $('#commonName').val()

    zip = new JSZip()
    zip.file cn + ".key", pem.private
    zip.file cn + ".csr", pem.csr

    content = zip.generate type: 'blob'
    saveAs content, cn + ".zip"

  showDone = () ->
    contentCSR.text pem.csr
    $ '#modalDone'
    .on 'hide.bs.modal', () ->
      # restore inputs and status
      txtStatus
        .attr 'class', 'alert alert-info'
        .html '<p>Ready to generate your CSR.</p>'
      input.attr "disabled", false
      # clean tempStorage
      pem = {}
      contentCSR.text ""
    .modal()
  generate = () ->
    input.each () ->
      self = $ this
    worker = new Worker "worker.js"
    worker.onmessage = (e) ->
      return unless e.data
      switch e.data.type
        when 'status'
          txtStatus.html "<p>#{e.data.message}</p>"
        when 'done'
          txtStatus.html "<p>Done.</p>"
          showDone()
        when 'private'
          pem.private = e.data.pem
        when 'csr'
          pem.csr     = e.data.pem

    worker.postMessage
      type: "start"
      workload: (() ->
        ret = {}

        input.each () ->
          self = $(this)
          ret[self.attr('id')] = self.val().trim()

        ret
      )()

  # bind events
  btnDownload.click (e) ->
    downloadCSRBundle()
    e.preventDefault()
  input.change () ->
    self = $(this)
    if self.val().trim() is ""
      self.parent().addClass 'has-warning'
    else
      self.parent().removeClass 'has-warning'
  form.submit (e) ->
    e.preventDefault()

    # validate form
    pass = true
    input.each () ->
      self = $(this)
      if self.val().trim() is ""
        self.parent().addClass 'has-warning'
        self.focus()
        pass = false
    return unless pass
    input.attr "disabled", true
    generate()
