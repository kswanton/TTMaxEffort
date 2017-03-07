using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Timer as Tmr;
using Toybox.Time as Time;
using Toybox.Graphics as Gfx;

class TTMaxEffortView extends Ui.DataField {

	const TIMERRES = 250;
	const SCREENBUFFER = 10;
	const BARWIDTH = 15;
	const ARROWWIDTH = 15;
	const ARROWHEIGHT = 10;

    hidden var _curPower = 0;
    hidden var _curHR = 0;
    hidden var _curCad = 0;
    hidden var _curSpeed = 0;
	hidden var _target;
	hidden var _isShown = false;
	hidden var _totalTicks = 0;
	hidden var _lastAlert = 0;

    function initialize() {
        DataField.initialize();
        _curPower = 0.0f;
        
        _target = Application.getApp().getProperty("FTP");
        
        Sys.println(_target.toString());
    }

    // Set your layout here. Anytime the size of obscurity of
    // the draw context is changed this will be called.
    function onLayout(dc) {
        var obscurityFlags = DataField.getObscurityFlags();

        // Top left quadrant so we'll use the top left layout
        if (obscurityFlags == (OBSCURE_TOP | OBSCURE_LEFT)) {
            View.setLayout(Rez.Layouts.TopLeftLayout(dc));

        // Top right quadrant so we'll use the top right layout
        } else if (obscurityFlags == (OBSCURE_TOP | OBSCURE_RIGHT)) {
            View.setLayout(Rez.Layouts.TopRightLayout(dc));

        // Bottom left quadrant so we'll use the bottom left layout
        } else if (obscurityFlags == (OBSCURE_BOTTOM | OBSCURE_LEFT)) {
            View.setLayout(Rez.Layouts.BottomLeftLayout(dc));

        // Bottom right quadrant so we'll use the bottom right layout
        } else if (obscurityFlags == (OBSCURE_BOTTOM | OBSCURE_RIGHT)) {
            View.setLayout(Rez.Layouts.BottomRightLayout(dc));

        // Use the generic, centered layout
        } else {
            View.setLayout(Rez.Layouts.MainLayout(dc));
        }

        return true;
    }

    // The given info object contains all the current workout information.
    // Calculate a value and save it locally in this method.
    // Note that compute() and onUpdate() are asynchronous, and there is no
    // guarantee that compute() will be called before onUpdate().
    function compute(info) {
        // See Activity.Info in the documentation for available information.
        if(info has :currentPower){
            if(info.currentPower != null){
                _curPower = info.currentPower;
            } else {
                _curPower = 0;
            }
        }
        
        if(info has :currentCadence){
            if(info.currentCadence != null){
                _curCad = info.currentCadence;
            } else {
                _curCad = 0;
            }
        }
        
        if(info has :currentHeartRate){
            if(info.currentHeartRate != null){
                _curHR = info.currentHeartRate;
            } else {
                _curHR = 0;
            }
        }
        
        if(info has :currentSpeed){
            if(info.currentSpeed != null){
                _curSpeed = info.currentSpeed;
            } else {
                _curSpeed = 0;
            }
        }
        
        _totalTicks++;
        
        var diviation = (((_curPower.toFloat() / _target.toFloat()) * 100f).toNumber() - 100).abs();
		var secsBetweenAlert = 0;
		
		if (diviation > 30) {
			// Assume they gave up...
			secsBetweenAlert = 0;
		} else if (diviation > 15) {
			secsBetweenAlert = 1;
		} else if (diviation > 10) {
			secsBetweenAlert = 2;
		} else if (diviation > 5) {
			secsBetweenAlert = 3;
		} else {
			secsBetweenAlert = 0;
		}
		
		
		if (secsBetweenAlert > 0 
				&& _totalTicks - _lastAlert >= secsBetweenAlert) {
			Toybox.Attention.playTone(Toybox.Attention.TONE_CANARY);
			_lastAlert = _totalTicks;		
		}
    }

    // Display the value you computed here. This will be called
    // once a second when the data field is visible.
    function onUpdate(dc) {
        // Set the background color
        View.findDrawableById("Background").setColor(getBackgroundColor());

        // Call parent's onUpdate(dc) to redraw the layout
        View.onUpdate(dc);
        
		/* 
		We'll knock off a bunch of the overall power zones
		for the rider.  No need to display 0% - 70%, as if they're down there
		we'll just put the marker against the bottom pin and assume they've cracked
		or they've spotted a coffee shop, decided to abandon their TT and are
		coasting to slow down to get a cup.
		We'll also clip anything over 110% as if you're above that in a TT, you're doing
		it wrong.  
		
		Zones:
		70% - 85%, Color red.
		85% - 90%, Color orange
		90% - 95%, Color yellow
		95% - 105%, Color green
		>= 105%, Color red
		
		*/
		
		var zones = [ 
			[70,  85,  0xff0000], 
			[85,  90,  0xff8000],
			[90,  95,  0xffff00],
			[95,  105, 0x00ff00],
			[105, 110, 0xff0000]
		];
		
		var fgcolor = 0;
		var bgcolor = 0;
		
		if (getBackgroundColor() == Gfx.COLOR_BLACK) {
            fgcolor = Gfx.COLOR_WHITE;
            bgcolor = Gfx.COLOR_BLACK;
        } else {
            fgcolor = Gfx.COLOR_BLACK;
            bgcolor = Gfx.COLOR_WHITE;
        }
		
		var barHeight = dc.getHeight() - (SCREENBUFFER * 2);
		var zone1Height =  0;
        var totalZoneSpread = zones[zones.size() - 1][1] - zones[0][0];
        var maxX = 0;
        
        var cursor = SCREENBUFFER;
        
        for(var idx = 0; idx < zones.size(); idx++){
        	var sectionHeight = barHeight.toFloat() * ((zones[idx][1] - zones[idx][0]).toFloat() / totalZoneSpread.toFloat());
        	
        	dc.setColor(zones[idx][2], zones[idx][2]);
        	dc.fillRectangle(
        		(SCREENBUFFER * 2) + (BARWIDTH), 
        		cursor, 
        		BARWIDTH, 
        		sectionHeight);
        	
        	dc.setColor(fgcolor, bgcolor);
        	
        	// Draw the watt cnt.
        	var watts = (_target.toFloat() * (zones[idx][0].toFloat() / 100f)).toLong().toString() + "w";
        	var dims = dc.getTextDimensions(watts, Gfx.FONT_SMALL);
        	
        	dc.drawText(
        		(SCREENBUFFER * 4) + BARWIDTH, 
        		idx == 0 ? cursor : cursor - (dims[1].toFloat() / 2f), 
        		Gfx.FONT_SMALL, 
        		watts, 
        		Gfx.TEXT_JUSTIFY_LEFT);
        		
        	if ((SCREENBUFFER * 4) + BARWIDTH + dims[0] > maxX) {
        		maxX = (SCREENBUFFER * 4) + BARWIDTH + dims[0];
        	}
        	
        	cursor += sectionHeight;
        }
        
        // Alright, now we need to draw the arrow/triangle to show where we're at.
        // Determine current power compared to FTP.
        var currentPer = 0f;
        
        if (_curPower > 0 && _target > 0){
        	currentPer = (_curPower.toFloat() / _target.toFloat()) * 100f;
        }
        
        var drawPoint = 0;
        
        if (currentPer <= zones[0][0].toFloat()) {
        	drawPoint = SCREENBUFFER;
        } else if (currentPer >= zones[zones.size() - 1][1].toFloat()){
        	drawPoint = barHeight + SCREENBUFFER;
        } else {
        	// Figure out where we're at.
        	var pixelsPerPercent = barHeight.toFloat() / totalZoneSpread.toFloat();
        	var perctgFromBase = currentPer - zones[0][0];
        	drawPoint = SCREENBUFFER + (pixelsPerPercent * perctgFromBase).toLong();
        }
        
        dc.setColor(fgcolor, bgcolor);
        
        dc.fillPolygon( [
        					[SCREENBUFFER + ARROWWIDTH, drawPoint], 
        					[SCREENBUFFER, drawPoint - ARROWHEIGHT], 
        					[SCREENBUFFER, drawPoint + ARROWHEIGHT]
        				]);
        				
        // At this point, the bar, arrow and zones have been painted.
        // We'll squeeze in HR, current power, cadence and speed in.
        
        // Work out speed, as the info is provided in m/s, and users will
        // do better in km/hr.
        var speedKMHR = "0";
        
        if (_curSpeed > 0) {
        	speedKMHR = ((_curSpeed * 60 * 60).toFloat() / 1000f).format("%.2f");
        }
        
        var infos = [
        	[ "Power", _curPower.toString() ],
        	[ "HR", _curHR.toString() ],
        	[ "Cadence", _curCad.toString() ],
        	[ "Speed", speedKMHR ]
        ];
        
        var paddedHeight = dc.getHeight() - (SCREENBUFFER * 2);
        var blockHeight = (paddedHeight.toFloat() / infos.size().toFloat()).toLong();
        var infoCenterline = (((dc.getWidth() - SCREENBUFFER - maxX).toFloat() / 2f) + maxX.toFloat()).toLong();
        
        for (var idx = 0; idx < infos.size(); idx++){
        	var lbldims = dc.getTextDimensions(infos[idx][0], Gfx.FONT_SMALL);
        	var valdims = dc.getTextDimensions(infos[idx][1], Gfx.FONT_MEDIUM);
        	var blockBaseline = SCREENBUFFER + (blockHeight * idx) + (blockHeight.toFloat() / 2f).toLong();
        	
        	dc.setColor(Gfx.COLOR_DK_GRAY, bgcolor);
        	dc.drawText(
        		infoCenterline - (lbldims[0].toFloat() / 2f).toLong(),
        		blockBaseline - lbldims[1],
        		Gfx.FONT_SMALL,
        		infos[idx][0],
        		Gfx.TEXT_JUSTIFY_LEFT);
        		
        	dc.setColor(fgcolor, bgcolor);
        		
        	dc.drawText(
        		infoCenterline - (valdims[0].toFloat() / 2f).toLong(),
        		blockBaseline,
        		Gfx.FONT_MEDIUM,
        		infos[idx][1],
        		Gfx.TEXT_JUSTIFY_LEFT);
        		
        	if (idx < infos.size() - 1){
        		
        		dc.setColor(Gfx.COLOR_DK_GRAY, bgcolor);
        		dc.setPenWidth(3);
        		dc.drawLine(
        			maxX + SCREENBUFFER, 
        			(blockHeight * (idx + 1)) + SCREENBUFFER,
        			dc.getWidth() - SCREENBUFFER,
        			(blockHeight * (idx + 1)) + SCREENBUFFER);
        		
        	}
        }
    }
    
    function onShow(){
    	_isShown = true;
    }
    
    function onHide(){
    	_isShown = false;
    }

}
