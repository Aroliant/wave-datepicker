((root, factory) ->
  # Define AMD module if AMD support exists.
  if typeof define is 'function' and define.amd
    define ['jquery'], ($) ->
      root.WDP = factory($)
  # Otherwise attach module to root.
  else
    root.WDP = factory(root.$)
)(this, ($) ->

  # Namespace to export
  WDP = {}

  # Default template
  # .dropdown-menu is hidden by default
  WDP.template = '
    <div class="wdp dropdown-menu">
      <div class="row-fluid">
        <div class="span5 wdp-shortcuts">
        </div>
        <div class="span7">
          <table class="table-condensed wdp-calendar">
            <thead>
              <tr>
                  <th class="wdp-prev">
                    <a href="javascript:void(0)" class="js-wdp-prev"><i class="icon-arrow-left"/></a>
                  </th>
                  <th colspan="5" class="wdp-month-and-year">
                  </th>
                  <th class="wdp-next">
                    <a href="javascript:void(0)" class="js-wdp-next"><i class="icon-arrow-right"/></a>
                  </th>
              </tr>
            </thead>
            <tbody>
            </tbody>
          </table>
        </div>
      </div>
    </div>'


  # Date parsing and formatting utils
  WDP.DateUtils =
    format: (date, format) -> moment(date).format(format)
    parse: (str, format) -> moment(str, format)


  # Allow users to set their own template and date functions
  WDP.configure = (options) ->
    WDP.template = options.template or WDP.template
    WDP.DateUtils.format = options.dateFormat or WDP.DateUtils.format
    WDP.DateUtils.parse = options.dateParse or WDP.DateUtils.parse


  # For keydown event handler
  LEFT = 37
  UP = 38
  RIGHT = 39
  DOWN = 40
  RETURN = 13
  KEY_H = 72
  KEY_J = 74
  KEY_K = 75
  KEY_L = 76

  # Class for handling shortcuts on the datepicker.
  class WDP.Shortcuts
    # Shortcut key shows as links on left side of picker.
    #
    # The value is an object representing offsets from today's date.
    #
    # Offsets are processed using the `add` function from
    # [moment.js](http://momentjs.com/docs/#/manipulating/add/).
    _defaults:
      'Today':
        days: 0

    currHighlightedIndex: 0

    constructor: (@options = {}) ->
      @options or= @_defaults
      @$el = $ '<ul>'
      @$el.on 'click', @_onShortcutClick

    render: ->
      shortcuts = []
      @numShortcuts = 0
      for name, offset of @options
        shortcuts.push "<li><a data-days=\"#{offset.days or 0}\" 
          data-months=\"#{offset.months or 0}\"
          data-years=\"#{offset.years or 0}\"
          data-shortcut-num=\"#{@numShortcuts}\"
          class=\"wdp-shortcut js-wdp-shortcut\" 
          href=\"javascript:void(0)\">
          #{name}</a></li>"
        @numShortcuts++
      @$el.html shortcuts.join ''
      @updateHighlighted()
      return this

    resetClass: ->
      @$el.find('.wdp-shortcut-active').removeClass('wdp-shortcut-active')
      @resetHighlighted()

    resetHighlighted: ->
      @$el.find('.wdp-shortcut-highlighted').removeClass 'wdp-shortcut-highlighted'

    highlightNext: =>
      @currHighlightedIndex = (@currHighlightedIndex + 1) % @numShortcuts
      @updateHighlighted()

    highlightPrev: =>
      @currHighlightedIndex = (@currHighlightedIndex - 1) % @numShortcuts
      # modulo doesn't work on negative numbers :(
      if @currHighlightedIndex < 0
        @currHighlightedIndex = @numShortcuts - 1
      @updateHighlighted()

    updateHighlighted: =>
      @resetHighlighted()
      @$el.find(".wdp-shortcut[data-shortcut-num=#{@currHighlightedIndex}]").addClass 'wdp-shortcut-highlighted'

    _onShortcutClick: (e) =>
      @select $(e.target)

    select: ($target) ->
      data = $target.data()
      wrapper = moment(new Date())
      offset =
        days: data.days
        months: data.months
        years: data.years
      wrapper.add offset

      @resetClass()
      $target.addClass 'wdp-shortcut-active'

      @$el.trigger 'dateselect', wrapper.toDate()

    selectHighlighted: =>
      $highlighted = @$el.find('.wdp-shortcut-highlighted')
      if $highlighted.length
        @select $highlighted

  class WDP.WaveDatepicker
    _defaultFormat: 'YYYY-MM-DD'

    # State our picker is currently in.
    # Month and year affect the calendar.
    _state: null

    constructor: (@options) ->
      @el = @options.el
      @$el = $(@el)

      @dateFormat = @options.format or @_defaultFormat

      @_state = {}

      @_updateFromInput()

      @_initPicker()
      @_initElements()
      @_initEvents()

      # e.g. 'today' -> sets calendar value to today's date
      @shortcuts = new WDP.Shortcuts(options.shortcuts).render()
      @$shortcuts.append @shortcuts.$el
      @$shortcuts.on 'dateselect', (e, date) => @setDate(date)

    render: =>
      @_updateMonthAndYear()
      @_fill()
      @_updateSelection()
      return this

    show: =>
      @$datepicker.addClass 'show'
      @height = @$el.outerHeight()
      @_place()
      @$window.on 'resize', @_place

    hide: =>
      @$datepicker.removeClass 'show'
      @$window.off 'resize', @_place

    # Sets the Date object for this widget and update `<input>` field.
    setDate: (date) =>
      @date = date
      @_state.month = @date.getMonth()
      @_state.year = @date.getFullYear()
      @$el.val @_formatDate(date)
      @$el.trigger 'datechange', @date

    getDate: -> @date

    # Navigate to prev month.
    prev: =>
      if @_state.month is 1
        @_state.month = 12
        @_state.year -= 1
      else
        @_state.month -= 1
      @render()

    # Navigate to next month.
    next: =>
      if @_state.month is 12
        @_state.month = 1
        @_state.year += 1
      else
        @_state.month += 1
      @render()

    destroy: =>
      @$datepicker.remove()
      @$el.removeData('datepicker')

    # Navigate to the previous month and select the date clicked
    _prevSelect: (e) =>
      @prev
      @_selectDate e

    # Navigate to the next month and select the date clicked
    _nextSelect: (e) =>
      @next
      @_selectDate e

    _initElements: ->
      if @options.className
        @$el.addClass(@options.className)

      # Set initial date value
      @$el.val @_formatDate(@date)

      # Set up elements cache
      @$shortcuts = @$datepicker.find '.wdp-shortcuts'
      @$calendar = @$datepicker.find '.wdp-calendar'
      @$tbody = @$calendar.find 'tbody'
      @$monthAndYear = @$calendar.find '.wdp-month-and-year'
      @$window = $ window

    # Renders the widget and append to the `<body>`
    _initPicker: ->
      @$datepicker = $ WDP.template
      @$datepicker.appendTo document.body

      weekdays = moment.weekdaysMin.join '</th><th>'

      @$datepicker.find('thead').append "<tr class=\"wdp-weekdays\"><th>#{weekdays}</th></tr>"

    _initEvents: ->
      # Show and hide picker
      @$el.on('focus', @show)
      @$el.on('blur', @hide)
      @$el.on 'change', @_updateFromInput
      @$el.on 'datechange', @render
      @$el.on 'keydown', @_onInputKeyDown

      @$datepicker.on 'mousedown', @_cancelEvent
      @$datepicker.on 'click', '.js-wdp-calendar-cell', @_selectDate
      @$datepicker.on 'click', '.js-wdp-prev', @prev
      @$datepicker.on 'click', '.js-wdp-prev-select', @_prevSelect
      @$datepicker.on 'click', '.js-wdp-next', @next
      @$datepicker.on 'click', '.js-wdp-next-select', @_nextSelect

    _updateFromInput: =>
      # Reads the value of the `<input>` field and set it as the date.
      if (dateStr = @$el.val())
        @date = @_parseDate dateStr

      # If date could not be set from @$el.val() then set to today.
      @date or= new Date()

      @setDate @date

    # Updates the picker with the current date.
    _updateMonthAndYear: =>
      date = new Date(@_state.year, @_state.month, 1)
      monthAndYear = moment(date).format('MMMM YYYY')
      @$monthAndYear.text monthAndYear

    _formatDate: (date) -> WDP.DateUtils.format(date, @dateFormat)

    _parseDate: (str) -> WDP.DateUtils.parse(str, @dateFormat).toDate()

    # Places the datepicker below the input box
    _place: =>
      zIndex = parseInt(
        @$el.parents().filter(-> $(this).css('z-index') isnt 'auto').first().css('z-index')
        , 10) + 10

      offset = @$el.offset()

      @$datepicker.css(
        top: offset.top + @height
        left: offset.left
        zIndex: zIndex
      )

    # Fills in calendar based on month and year we're currently viewing.
    _fill: ->
      # Set to the year and month from state, and the day is the first of the month.
      date = new Date(@_state.year, @_state.month, 1)

      index = 0  # Current index for the calendar cells.

      html = []  # array for holding HTML of the calendar

      wrapped = moment date
      daysInMonth = wrapped.daysInMonth()

      startOfMonth = wrapped.clone().startOf('month')
      endOfMonth = wrapped.clone().endOf('month')

      # 0 == Sun, 1 == Mon, ..., 6 == Sat
      firstDateDay = startOfMonth.day()
      lastDateDay = endOfMonth.day()
      paddingStart = 0

      # If start date is not Sun then padd beginning of calendar.
      if firstDateDay isnt 0
        prevMonth = startOfMonth.clone()

        for i in [0..firstDateDay-1]
          if (index++) is 0
            html.push '<tr class="wdp-calendar-row">'
          d = prevMonth.add('days', -1).date()
          formattedPrevMonth = @_formatDate new Date(@_state.year, @_state.month - 1, d)
          # + 1 because element at index zero is the <tr>
          html[6 - i + 1] = "<td class=\"wdp-calendar-othermonth js-wdp-prev-select\" data-date=\"#{formattedPrevMonth}\">#{d}</td>"
          paddingStart++

      # For formatting purposes in the following loop.
      currMonth = new Date(@_state.year, @_state.month, 1)

      # Fill in dates for this month.
      for i in [1..daysInMonth]
        currMonth.setDate(i)
        formatted = @_formatDate currMonth
        if (index++) % 7 is 0
          html.push '</tr><tr class="wdp-calendar-row">'
        html.push "<td class=\"js-wdp-calendar-cell\" data-date=\"#{formatted}\">#{i}</td>"

      # Fill out the rest of the calendar (six rows).
      nextMonth = endOfMonth.clone()
      while index < 42  # 7 * 6 = 42
        d = nextMonth.add('days', 1).date()
        formattedNextMonth = @_formatDate new Date(@_state.year, @_state.month + 1, d)
        if (index++) % 7 is 0
          html.push '</tr><tr class="wdp-calendar-row">'
        html.push "<td class=\"wdp-calendar-othermonth js-wdp-next-select\" data-date=\"#{formattedNextMonth}\">#{d}</td>"

      html.push '</tr>'

      @$tbody.html html.join ''

    _cancelEvent: (e) => e.stopPropagation(); e.preventDefault()

    _onInputKeyDown: (e) =>
      if e.keyCode is DOWN or e.keyCode is KEY_J
        @_cancelEvent e
        fn = @shortcuts.highlightNext
        offset = 7

      else if e.keyCode is UP or e.keyCode is KEY_K
        @_cancelEvent e
        fn = @shortcuts.highlightPrev
        offset = -7

      else if e.keyCode is LEFT or e.keyCode is KEY_H
        @_cancelEvent e
        offset = -1

      else if e.keyCode is RIGHT or e.keyCode is KEY_L
        @_cancelEvent e
        offset = 1

      else if e.keyCode is RETURN
        fn = @shortcuts.selectHighlighted
        @_cancelEvent e

      if e.shiftKey and offset?
        date = new Date(@date.getFullYear(), @date.getMonth(), @date.getDate() + offset)
        @setDate date
      else
        fn?()

    _updateSelection: ->
      # Update selection
      dateStr = @_formatDate @date
      @$tbody.find('.wdp-selected').removeClass('wdp-selected')
      @$tbody.find("td[data-date=#{dateStr}]").addClass('wdp-selected')

    _selectDate: (e) =>
      @shortcuts.resetClass()
      date = @_parseDate $(e.target).data('date')
      @setDate date


  # Add jQuery widget
  $.fn.datepicker = (options = {}, args...) ->
    # Calling a method on widget.
    # Prevent methods beginning with _ to be called because they are private
    if typeof options is 'string' and options[0] isnt '_' and options isnt 'render'
      widget = $(this).data('datepicker')
      return widget?[options].apply widget, args

    @each ->
      $this = $ this
      widget = $this.data('datepicker')
      $.extend options, {el: this}

      unless widget
        $this.data 'datepicker', (widget = new WDP.WaveDatepicker(options).render())


  return WDP
)
