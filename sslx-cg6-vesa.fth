\
\ SPARCstation LX builtin cg6 Framebuffer PROM
\
\ Taken from the SPARCstation LX OpenBoot
\
FCode-version1
offset16

hex		\ all numbers are in hex


" cgsix" 		name
" SUNW,501-1672"	model
" display"		device-type

: copyright	" Copyright (c) 1990 by Sun Microsystems, Inc. " ;
: sccsid	" @(#)obduplo.fth 1.33 92/10/23" ;


variable	legosc-address


: map-slot ( offset size -- virtaddr )
	swap legosc-address @ + swap map-low
;


4	constant lengthloc	\ prom+0x04 contains fcode length

10	constant /dac		\ dac register size
8000	constant /prom		\ prom size

58a28d4	constant mainosc	\ unused


-1	value dac-adr
-1	value prom-adr
-1	value ptr
-1	value logo
-1	value fhc
-1	value thc
-1	value fbc-adr
-1	value fb-addr
-1	value alt-adr
-1	value tec
-1	value tmp-len
-1	value tmp-addr
-1	value tmp-flag
-1	value selftest-map

0	value mapped?
0	value alt-mapped?

0	value my-reset

1	value /vmsize
8	value ppc
91	value bdrev
1238	value strap-value
200000	value /frame


100 alloc-mem	constant data-space


external

0	value display-width
0	value display-height
0	value dblbuf?
-1	value acceleration

headers


0	value lego-status
0	value sense-id-value
0	value chip-rev


defer (set-fbconfiguration
defer (confused?
defer fbprom


\ Declare an attribute with the given value.
: my-attribute ( xdr-adr xdr-len name-adr name-len -- )
	fcode-revision 2000 < if
		\ Old OpenBoot does not support attributes.
		2drop 2drop
	else
		my-reset 0 = if
			attribute
		else
			\ Currently resetting, do nothing.
			2drop 2drop
		then
	then
;


: my-xdrint ( n -- xdr-adr xdr-len )
	my-reset 0= if
		xdrint		( xdr-adr xdr-len )
	else
		0		( n 0 )
	then
;


: my-xdrstring ( adr len -- xdr-adr xdr-len )
	my-reset 0= if
		xdrstring	( xdr-adr xdr-len )
	then
;


\ Ask OBP for PROM address.
: hobbes-prom ( -- prom-addr )
	" fb-prom" $find drop to fbprom
	fbprom
;


\ Get the FCode length.  It is encoded as bytes 5-8 of the FCode header.
: length@ ( -- length )
	\ Take the FCode start address and add 4.  Read that address' value
	\ and leave it on the stack.
	hobbes-prom lengthloc + l@
;


\
\ The logo sits right behind the FCode in the PROM.  Return its start address.
\
\ TODO: When modifying the CG6 PROM, the logo needs to be copied too!  The logo
\ contains a palette, so using random data will mess up the screen.
\
: logo-data ( -- logo-addr )
	hobbes-prom length@ +	( end-of-prom )
	
	\ Increment address until addr % 4 == 0.
	begin
		dup 3 and
	while
		1 +
	repeat
;


\ Access FBC - FrameBuffer Controller
: fbc!	( value offset -- )	fbc-adr + l! ;
: fbc@	( offset -- value )	fbc-adr + l@ ;

\ Access FHC - FBC Hardware Configuration
: fhc!	( value offset -- )	fhc + l! ;
: fhc@	( offset -- value )	fhc + l@ ;

\ Access TEC - Transformation Engine and Cursor
: tec!	( value offset -- )	tec + l! ;

\ Access THC - TEC Hardware Configuration
: thc!	( value offset -- )	thc + l! ;
: thc@	( offset -- value )	thc + l@ ;

\ Access DAC - Digital to Analog Converter
: dac!	( value offset -- )	dac-adr + l! ;

\ Access ALT
\ According to [800-5114-10] this is set aside for future expansion and will
\ be used for selecting the optional oscillators.
: alt!	( value offset -- )	alt-adr + l! ;


\ Wait until bit 28 (BUSY) of the FBC status register is clear.
: fbc-busy-wait ( -- ) begin 10 fbc@ 10000000 and 0= until ;

\ Wait until bit 29 (FULL) of the FBC drawstatus register is clear.
: fbc-draw-wait ( -- ) begin 14 fbc@ 20000000 and 0= until ;

\ Wait until bit 29 (FULL) of the FBC blitstatus register is clear.
: fbc-blit-wait ( -- ) begin 18 fbc@ 20000000 and 0= until ;


: background-color
	\ This is an OBP variable!
	inverse-screen? if
		ff
	else
		0
	then
;


: rect-fill ( x1 y1 x2 y2 color -- )
	fbc-busy-wait
	100 fbc!	( x1 y1 x2 y2 )		\ set pen color
	2swap		( x2 y2 x1 y1 )
	904 fbc!	( x2 y2 x1 )
	900 fbc!	( x2 y2 )
	904 fbc!	( x2 )
	900 fbc!	( )
	fbc-draw-wait				\ wait untill drawn
	fbc-busy-wait
	ff 100 fbc!				\ reset pen color
;


\ Convert character cell position to pixel position.
: >pixel ( col row -- x y )
	swap char-width * window-left +		( row x )
	swap char-height * window-top +		( x y )
;


\ Fill a rectangle in background color.  The rectangle is given in character
\ cell positions.
: char-fill ( col1 row1 col2 row2 )
	2swap >pixel 2swap >pixel	( x1 y1 x2 y2 )
	background-color rect-fill
;


\ Initialize FB for BLITs (BLock Image Transfers.)
: init-blit-reg ( -- )
	fbc-busy-wait

	ffffffff 10 fbc!	\ STATUS

	0 4 tec!

	\ VESA: this is just to save 4 bytes...
	0 8 fbc!		\ CLIPCHECK
	\ h# 0 8 fbc!		\ CLIPCHECK

	h# 0 c0 fbc!		\ RASTEROFFX
	h# 0 c4 fbc!		\ RASTEROFFY

	h# 0 d0 fbc!		\ AUTOINCX
	h# 0 d4 fbc!		\ AUTOINCY

	h# 0 e0 fbc!		\ CLIPMINX
	h# 0 e4 fbc!		\ CLIPMINY

	ff 100 fbc!		\ FCOLOR
	h# 0 104 fbc!		\ BCOLOR

	a980.6c60 108 fbc!	\ RASTEROP

	ff 10c fbc!		\ PLANEMASK
	ffff.ffff 110 fbc!	\ PIXELMASK

	h# 0 11c fbc!		\ PATTALIGN

	\ PATTERN0..PATTERN7
	ffffffff 120 fbc! ffffffff 124 fbc! ffffffff 128 fbc! ffffffff 12c fbc!
	ffffffff 130 fbc! ffffffff 134 fbc! ffffffff 138 fbc! ffffffff 13c fbc!

	0022.9540 4 fbc!		\ MISC

	display-width 1 - f0 fbc!	\ CLIPMAXX
	display-height 1 - f4 fbc!	\ CLIPMAXY

	\
	\ Tell FHC the display width:
	\ - read fhc+0 (CONFIG)
	\ - clear bits 10-12 (e3 is 11100011)
	\ - set the right bits:
	\	8 is 010|00, 10 is 100|00, 18 is 110|00, 4 is 001|00
	\ - write the result back to fhc+0 (CONFIG)
	\
	\ NOTE: in the older docs only bits 11-12 are used, bit 10 was
	\ presumably added later to deal with higher resolutions.
	\
	display-width case
	d# 1024 of	ffffe3ff 0 fhc@ and          0 fhc!	endof
	d# 1152 of	ffffe3ff 0 fhc@ and 800 or   0 fhc!	endof
	d# 1280 of	ffffe3ff 0 fhc@ and 1000 or  0 fhc!	endof
	d# 1600 of	ffffe3ff 0 fhc@ and 1800 or  0 fhc!	endof
	d# 1920 of	ffffe3ff 0 fhc@ and 400 or   0 fhc!	endof
	endcase
;


: cg6-save ( -- x00..x22 )
	fbc-busy-wait

	c0 fbc@ c4 fbc@		\ RASTEROFFX RASTEROFFY
	d0 fbc@ d4 fbc@		\ AUTOINCX AUTOINCY
	e0 fbc@ e4 fbc@		\ CLIPMINX CLIPMINY
	8 fbc@			\ CLIPCHECK
	100 fbc@ 104 fbc@	\ FCOLOR BCOLOR
	108 fbc@		\ RASTEROP
	10c fbc@ 110 fbc@	\ PLANEMASK PIXELMASK
	4 fbc@			\ MISC
	f0 fbc@ f4 fbc@		\ CLIPMAXX CLIPMAXY
	80 fbc@ 84 fbc@		\ ?
	90 fbc@ 94 fbc@		\ ?
	a0 fbc@ a4 fbc@		\ ?
	b0 fbc@ b4 fbc@		\ ?

	init-blit-reg
;


: cg6-restore ( x0..x22 -- )
	fbc-busy-wait

	b4 fbc! b0 fbc!
	a4 fbc! a0 fbc!
	94 fbc! 90 fbc!
	84 fbc! 80 fbc!
	f4 fbc! f0 fbc!
	40 or 4 fbc!		\ MISC with Modify Adress Index bit set
	110 fbc! 10c fbc!
	108 fbc!
	104 fbc! 100 fbc!
	8 fbc!
	e4 fbc! e0 fbc!
	d4 fbc! d0 fbc!
	c4 fbc! c0 fbc!
;


variable tmp-blit


\ Blit a screen region given by character cells.
: lego-blit ( col0 row0 col1 row1 col2 row2 col3 row3 -- )
	fbc-busy-wait

	\ Copy (col0,row0)-(col1,row1) to (col2,row2)-(col3,row3)
	>pixel  1 -  b4 fbc!  1 -  b0 fbc!
	>pixel       a4 fbc!       a0 fbc!
	>pixel  1 -  94 fbc!  1 -  90 fbc!
	>pixel       84 fbc!       80 fbc!

	fbc-blit-wait
	fbc-busy-wait
;


\ Delete / clear lines starting with the current one.
: lego-delete-lines ( lines -- )

	dup #lines < if		\ clear fewer lines than total number on screen

		tmp-blit !
		cg6-save
		tmp-blit @

		>r

		\ Why not check if we need them *before* calculating these
		\ coordinates?

		\ (0,line#+lines)-(#columns,#lines)
		0  line# r@ +  #columns  #lines
		\ (0,line#)-(#columns,#lines-lines)
		0  line#       #columns  #lines r@ -

		line# r@ + #lines < if
				\ copy remaining lines if there are any

			lego-blit

		else		\ otherwise just drop the coordinates

			2drop 2drop 2drop 2drop

		then

		\ clear the bottom lines
		0  #lines r> - #columns  #lines
		char-fill

		cg6-restore

	else			\ delete the bottom lines

		tmp-blit !
		cg6-save
		tmp-blit @

		\ lines >= #lines so this should just clear the entire screen?
		\ Why bother calculating #lines-lines?
		0 swap			( 0 lines )
		#lines swap -		( 0 #lines-lines )
		#columns #lines		( 0 #lines-lines #columns #lines )
		char-fill

		cg6-restore

	then
;


\ Insert blank lines before the current, scrolling lower lines down.
: lego-insert-lines ( lines -- )

	dup #lines < if		\ add fewer lines than total number on screen

		tmp-blit !
		cg6-save
		tmp-blit @

		>r

		\ Copy from the current line down.
		0 line#       #columns  #lines r@ -
		0 line# r@ +  #columns  #lines
		lego-blit

		\ Erase lines beginning at the current one.
		0 line#       #columns  line# r> +
		char-fill

		cg6-restore

	else			\ simply clear this line and below

		tmp-blit !
		cg6-save
		tmp-blit @

		0 swap		( 0 lines )
		line# swap	( 0 line# lines )
		#columns swap	( 0 line# columns# lines )
		line# swap +	( 0 line# columns# line#+lines )
				\ we really didn't need that swap...
		char-fill	( -- )

		cg6-restore

	then
;


\ Clear screen by filling a rectangle with the background-color.
: lego-erase-screen ( -- )
	cg6-save
	0 0 screen-width screen-height background-color rect-fill
	cg6-restore
;


\
\ Based on what the below supposedly does, thc+818 should be the THC Misc
\ Register HCMISC.  Unfortunately, the relevant pages from the register summary
\ are missing.
\

\ Clear / Set bit 10 (ENABLE_VIDEO) and (for -off) set bit 12 (RESET)
: lego-video-on		818 thc@      400 or          818 thc! ;
: lego-video-off	818 thc@ fffffbff and 1000 or 818 thc! ;

\ Clear / Set bit 7 (ENABLE_SYNC)
: lego-sync-on		818 thc@       80 or          818 thc! ;
: lego-sync-off		818 thc@ ffffff7f and         818 thc! ;


: delay-100	1 ms ;


\ Set bit 12 (RESET) and wait.
: lego-sync-reset
	818 thc@ 1000 or 818 thc!
	delay-100
;


\
\ For the below (un)map functions, see the Global Address Map on p.2-11 of the
\ __Single Chip GX/TGX Product Family Hardware Theory of Operation Manual__ .
\
\	Part	Start Addr	End Addr
\	---------------------------------------
\	ROM	0x000000	0x1fffff
\	DAC	0x200000	0x27ffff
\	ALT	0x280000	0x280fff
\	FHC	0x300000	0x300fff
\	THC	0x301000	0x301fff
\	FBC	0x700000	0x700fff
\	TEC	0x701000	0x701fff
\	DFB	0x800000	0xffffff
\

: prom-map ( -- ) 0 /prom map-slot to prom-adr ;

: prom-unmap ( -- ) prom-adr /prom free-virtual -1 to prom-adr ;


: dac-map ( -- ) 240000 /dac map-slot to dac-adr ;

: dac-unmap ( -- ) dac-adr /dac free-virtual -1 to dac-adr ;


: fhc-thc-map ( -- ) 300000 2000 map-slot to fhc fhc 1000 + to thc ;

: fhc-thc-unmap ( -- ) fhc 2000 free-virtual -1 to fhc -1 to thc ;


: ?fhc-thc-map
	fhc -1 = if
		-1 to mapped?
		fhc-thc-map
	else
		0 to mapped?
	then
;


: ?fhc-thc-unmap
	mapped? if
		fhc-thc-unmap
		0 to mapped?
	then
;


: fb-map ( -- ) 800000 /frame map-slot to fb-addr ;

: fb-unmap ( -- ) fb-addr /frame free-virtual -1 to fb-addr ;


: fbc-map ( -- ) 700000 2000 map-slot to fbc-adr fbc-adr 1000 + to tec ;

: fbc-unmap ( -- ) fbc-adr 2000 free-virtual -1 to fbc-adr ;


: alt-map ( -- ) 280000 2000 map-slot to alt-adr ;

: alt-unmap ( -- ) alt-adr 2000 free-virtual -1 to alt-adr ;


: ?alt-map ( -- )
	alt-adr -1 = if
		-1 to alt-mapped?
		alt-map
	else
		0 to alt-mapped?
	then
;


: ?alt-unmap ( -- )
	alt-mapped? if
		alt-unmap
		0 to alt-mapped?
	then
;


\ Set color palette.
: color ( pal-addr n -- )
	dup		( pal-addr n n )
	rot + swap	( pal-addr+n n )
	0 dac-adr l!				\ write 0 to DAC+0x00
	do
		i c@				\ read byte
		dup 18 lshift +
		dac-adr 4 + l!			\ write to DAC+0x04
	loop
;


: 3color! ( r g b c# -- )
	dac-adr l!	( r g b )		\ store c# in dac-adr
	swap rot	( b g r )
	3 0 do
		dac-adr 4 + l!			\ store color components
	loop
;


\ Set color palette (dac-reg=4) or overlay color (dac-reg=c).
: color! ( c c# dac-reg -- )
	swap		( c dac-reg c# )
	0 dac!		( c dac-reg )		\ c# 0 dac!
	2dup dac!	( c dac-reg )
	2dup dac!	( c dac-reg )
	dac!
;


\
\ Initialize the LX's BrookTree 467 RAMDAC.
\
\ Local Data Bus lines LD[31..24] are loaded into the Address Register.
\
\	DAC Addr	Register
\	--------------------------------
\	0x04		Read Mask
\	0x05		Blink Mask
\	0x06		Command
\	0x07		Test
\	0x09		?
\
\ NOTE: This is based on olders docs, the newer _TurboGX Reference Card_ is
\ considered lost.  If you have it, please send me a copy!
\ 
: lego-init-dac
	dac-map

	0600.0000 0 dac! 4300.0000 8 dac!	\ Command:    0100.0011
	0500.0000 0 dac! h# 0      8 dac!	\ Blink Mask: 0000.0000
	0400.0000 0 dac! ff00.0000 8 dac!	\ Read Mask:  1111.1111
	0700.0000 0 dac! h# 0      8 dac!	\ Test:       0000.0000
	0900.0000 0 dac! 0600.0000 8 dac!	\ ?:          0000.0110

	\ Initialize color palette.
	ff00.0000  h# 0       4 color!		\ entry 00 is white
	h# 0       ff00.0000  4 color!		\ entry ff is black

	\ Initialize overlay colors.
	ff00.0000  0100.0000  c color!		\ overlay 1 is white
	h# 0       0200.0000  c color!		\ overlay 2 is black
	h# 0       0300.0000  c color!		\ overlay 3 is black

	\ Typical blue-ish purple Sun logo color.
	6400.0000 4100.0000 b400.0000 0100.0000 3color!

	dac-unmap
;


\
\ Preconfigured resolutions.
\

external

\ osc,hfrq,vfrq,hfporch,hsyncw,hbporch,hdisp,vfporch,vsyncw,vbporch,vdisp,flags
: r1024x768x60 " 64125000,48286,60,16,128,160,1024,2,6,29,768,COLOR" ;
: r1024x768x70 " 74250000,56593,70,16,136,136,1024,2,6,32,768,COLOR" ;
: r1024x768x76 " 81000000,61990,76,40,128,136,1024,2,4,31,768,COLOR,0OFFSET" ;
: r1024x768x77 " 84375000,62040,77,32,128,176,1024,2,4,31,768,COLOR,0OFFSET" ;
: r1024x800x72 " 81000000,60994,73,40,128,136,1024,2,4,31,800,COLOR,0OFFSET" ;
: r1024x800x74 " 84375000,62040,74,32,128,176,1024,2,4,31,800,COLOR,0OFFSET" ;
: r1024x800x85 " 94500000,71590,85,16,128,152,1024,2,4,31,800,COLOR,0OFFSET" ;
: r1152x900x66 " 94500000,61845,66,40,128,208,1152,2,4,31,900,COLOR" ;
: r1152x900x76 " 108000000,71808,76,32,128,192,1152,2,4,31,900,COLOR,0OFFSET" ;
\ VESA_1280x1024x60
: r1280x1024x60 " 108000000,63981,60,48,112,248,1280,1,3,38,1024,COLOR,0OFFSET" ;
: r1280x1024x67 " 118125000,71678,67,24,128,216,1280,2,8,41,1024,COLOR,0OFFSET" ;
\ : r1280x1024x76 " 135000000,81128,76,32,64,288,1280,2,8,32,1024,COLOR,0OFFSET" ;
\ VESA_1600x1200x60
: r1600x1200x60 " 162000000,75000,60,64,192,304,1600,1,3,46,1200,COLOR,0OFFSET" ;
\ : r1600x1280x76 " 216000000,101890,76,24,216,280,1600,2,8,50,1280,COLOR,0OFFSET" ;

: svga60	r1024x768x60 ;
: svga70	r1024x768x70 ;
: svga77	r1024x768x77 ;

headers


defer sense-code


\ Default display mode by sense-id *without* extra VRAM.
: legoSR-sense ( -- stradr strlen )
	sense-id-value case
	7 of	r1152x900x66	endof	\ no or unsupported monitor
	6 of	r1152x900x76	endof
	5 of	r1024x768x60	endof
	4 of	r1152x900x76	endof
	3 of	r1152x900x66	endof
	2 of	r1152x900x66	endof
	1 of	r1152x900x66	endof
	0 of	r1024x768x77	endof
	drop	r1152x900x66	0	\ invalid sense-id
	endcase
;


\ Default display mode by sense-id *with* extra VRAM.
: duploSR-sense ( -- stradr strlen )
	sense-id-value case
	7 of	r1152x900x66	endof	\ no or unsupported monitor
	6 of	r1152x900x76	endof
	5 of	r1024x768x60	endof
	4 of	r1152x900x76	endof
	3 of	r1152x900x66	endof
	2 of	r1280x1024x60	endof
	\ 2 of	r1280x1024x76	endof
	\ VESA_1600x1200x60
	1 of	r1600x1200x60	endof
	\ 1 of	r1600x1280x76	endof
	0 of	r1024x768x77	endof
	drop	r1152x900x66	0	\ invalid sense-id
	endcase
;


\
\ Set up ICS.
\
\ This is done by writing to ALT.  Unfortunately, I have no documentation.
\
\ The TurboGX+ code does each write twice, with and without bit 3 set.
\
: ics-write ( x y -- )
	1c lshift                0 alt!		\ write (y<<28) to alt+0
	1c lshift  0800.0000 or  0 alt!		\ write (x<<28)
;						\ with bit 3 of x set


\
\ Parameters to set up ICS timings.  There are 13 (d) parameters each.
\
\ These appear to be the ICS1562A registers 0-c in reverse order.  Registers
\ are 4-bits wide.
\
\ Reg	Bit	Reference	Description
\ ----------------------------------------------------------------------------
\ 0	0-3	R[0]..R[3]	reference divider modulus control bits
\ 1	0-2	R[4]..R[6]	modulus = value + 1
\	3	REFPOL		reference polarity (here: 0)
\ 2	0-3	A[0]..A[3]	A-counter control
\ 3	0-3	M[0]..M[3]	M-counter control
\ 4	0-1	M[4]..M[5]	modulus = value + 1
\	2	FBKPOL		feedback polarity (here: 0)
\	3	DBLFREQ		double A-modulus (here: 1)
\ 5	0-3	N1[0]..N1[3]	N1 modulus (here: 1 -> ratio 4)
\ 6	0-3	N2[0]..N2[3]	N2 divider modulus (here: 0)
\ 7	0-3	N2[4]..N2[7]
\ 8	3	N2[8]
\	0-2	V[0]..V[2]	VCO gain
\ 9	0-1	P[0]..P[1]	phase detector gain (here: 2)
\	3	P[2]		phase detector tuning (normally and here: 1)
\ a	1	LOADEN*		load clock divider (here: 0/active)
\	2	SKEW-		differential output duty adjust
\	3	SKEW+		(here: 0/default)
\ b	0-1	S[0]..S[1]	PLL post scaler (0: scaler=1, 1: scaler=2)
\	2	AUX_CLK		AUX clock control (here: 0)
\	3	AUX_N1		(here: 0)
\ c	0	RESERVED	must be 0
\	1	JAMPLL		(here: 0)
\	2	DACRST		(here: 0)
\	3	SELXTAL		(here: 0)
\ f	0	ALTLOOP		1: N1 and N2 dividers are used
\	3	PDRSTEN
\
\ Frequency is calculated as follows:
\
\ F[VCO] = (F[X1] * N) / ((R+1) * (S+1)) ,
\
\ where		N = ((M+1)*6) + A  for A != 0 , or
\		N = (M+1) * 7      for A == 0 ,
\		and F[X1] = 27MHz.
\
\ Finally, when register b is 1 the result is post-scaled (divided) by 2.
\
\                 S     V         M A   R
\ Reg:          c b a 9 8 7 6 5 4 3 2 1 0
\               v v v v v v v v v v v v v
: ics47		0 1 0 a 4 0 0 1 8 2 0 0 5 ;
: ics54		0 1 0 a 4 0 0 1 8 2 2 0 4 ;
: ics64		0 1 0 a 4 0 0 1 8 2 1 0 3 ;
: ics74		0 1 0 a 5 0 0 1 8 4 3 0 5 ;
: ics81		0 1 0 a 5 0 0 1 8 5 0 0 6 ;
: ics84		0 1 0 a 5 0 0 1 8 3 1 0 3 ;
: ics94		0 1 0 a 5 0 0 1 8 2 0 0 2 ;
: ics108	0 1 0 a 5 0 0 1 8 4 2 0 3 ;
: ics118	0 1 0 a 5 0 0 1 8 3 2 0 2 ;
: ics135	0 1 0 a 6 0 0 1 8 5 4 0 3 ;
\ VESA_1600x1200x60
: ics162	0 1 0 a 6 0 0 1 8 6 6 0 3 ;
\ : ics162	0 0 0 a 5 0 0 1 8 6 6 0 7 ;
: ics189	0 0 0 a 5 0 0 1 8 2 0 0 2 ;
\ : ics216	0 0 0 a 5 0 0 1 8 4 2 0 3 ;


\
\ Place a counted list of oscillator values on the stack.
\
\ NOTE: The order these are in is relevant and has to be the reverse of the
\ order in setup-oscillator !
\
: oscillators ( -- osc[0..n-1] n )
	\ 50775d8 4d3f640 46cf710 3d27848
	\ cdfe600 b43e940 80befc0 70a71c8
	\ 66ff300 5a1f4a0 337f980 2d0fa50
	d#  84.375.000	d#  81.000.000	d#  74.250.000	d#  64.125.000
	\ VESA_1600x1200x60
	d# 162.000.000	d# 189.000.000	d# 135.000.000	d# 118.125.000
	\ d# 216.000.000	d# 189.000.000	d# 135.000.000	d# 118.125.000
	d# 108.000.000	d#  94.500.000	d#  54.000.000	d#  47.250.000
	c	\ number of oscillator values
;


: setup-oscillator ( idx -- )
	?alt-map

	( idx ) case
	0 of	ics47	endof
	1 of	ics54	endof
	2 of	ics94	endof
	3 of	ics108	endof
	4 of	ics118	endof
	5 of	ics135	endof
	6 of	ics189	endof
	\ VESA_1600x1200x60
	7 of	ics162	endof
	\ 7 of	ics216	endof
	8 of	ics64	endof
	9 of	ics74	endof
	a of	ics81	endof
	b of	ics84	endof
	drop	ics94	0
	endcase

	\ Do an ics-write for each parameter.
	d 0 do
		i ics-write
	loop

	0 f ics-write

	\
	\ According to the ICS1562A datasheet I have, it needs 32 register
	\ writes for programming to become effective.  It is suggested to do
	\ dummy writes to the c or d register.  The TurboGX+ PROM contains the
	\ following code:
	\
	\ 20 0 do
	\	0 d ics-write
	\ loop
	\
	\ In fact, 19 (h# 13) dummy writes should be enough.
	\
	\ The LX contains an ICS1562M 9348-001 for which I have no datasheet
	\ so I'm not sure whether the same dummy writes should be done here.
	\

	94 thc@  40 or  dup 94 thc!  to strap-value

	1 ms

	?alt-unmap
;


variable dpl

: upper
	bounds ?do
		i dup c@
		upc swap c!
	loop
;


\ Compare two strings and return true if they match.
: compare-strings ( adr1 len1 adr2 len2 -- match )
	rot tuck	( adr1 adr2 len1 len2 len1 )
	< if			\ different lengths - no match
		3drop 0		\ return false
	else
		comp 0=		\ builtin comparison
	then
;


: long?		dpl @ 1 + 0<> ;


: convert
	begin
		1 + dup >r c@ a digit
	while
		>r a * r> + long? if
			1 dpl +!
		then
		r>
	repeat
	drop r>
;


: number?
	>r 0 r@ dup 1 + c@ 2d = dup >r - -1 dpl !
	begin
		convert dup c@ 2e =
	while
		0 dpl !
	repeat
	r> if
		swap negate swap
	then
	r> count + =
;


: number	number? drop ;


: /string	over min >r swap r@ + swap r> - ;
: +string	1 + ;
: -string	swap 1 + swap 1 - ;


: left-parse-string
	>r
	over 0 2swap
	begin
		dup
	while
		over c@ r@ = if
			r> drop -string 2swap
			exit
		then
		2swap +string
		2swap -string
	repeat
	2swap r> drop
;


: left-parse-string'
	left-parse-string
	2 pick 0= if
		2swap
	then
;


: cindex
	0 swap 2swap bounds
	?do
		dup
		i c@ = if
			nip i -1 rot leave
		then
	loop
	drop
;


: right-parse-string
	>r 2dup +
	0
	begin
		2 pick
	while
		over 1 -
		c@ r@ = if
			r> drop rot 1 - -rot
			exit
		then
		2swap 1 - 2swap swap 1 - swap 1 +
	repeat
	r>
	drop
;


variable cal-tmp
variable osc-tmp
variable confused?

100 alloc-mem constant tmp-monitor-string
100 alloc-mem constant tmp-pack-string


variable tmp-monitor-len


external

: monitor-string
	tmp-monitor-string tmp-monitor-len @
;

headers


: flag-strings
	" STEREO"
	" 0OFFSET"
	" OVERSCAN"
	" GRAY"
	4
;


: mainosc?
	-1 confused? ! 3e8 / osc-tmp ! oscillators 0
	do
		3e8 / osc-tmp
		@ = if
			i setup-oscillator
			0 confused? !
		then
	loop
;


: parse-string
	to tmp-len
	to tmp-addr
	to tmp-flag
	flag-strings 0
	do
		tmp-addr
		tmp-len
		2swap
		compare-strings if
			1 i lshift tmp-flag + to tmp-flag
		then
	loop
	tmp-flag
;


: parse-flags
	0 >r
	begin
		2c left-parse-string
		r>
		-rot parse-string
		>r
	dup 0= until
	2drop
	r>
;


: parse-line
	b 0
	do
		2c
		left-parse-string
		tmp-pack-string
		pack dup number
		swap drop -rot
		dup 0= if
			leave
		then
	loop
	dup 0<> if
		parse-flags
	else
		2drop 0
	then
;


: cycles-per-tran
	1add30 ppc * /mod swap 0<> if
		1 +
	then
	4 - dup f > if
		drop f
	then
;


: vert ( vfporch vsyncw vbporch vdisp -- )
	to display-height

	rot dup			( vsyncw vbporch vfporch vfporch )
	my-xdrint " vfporch" my-attribute
	1 - dup c0 thc!		( vsyncw vbporch vfporch-1 )
	rot dup			( vbporch vfporch-1 vsyncw vsyncw )
	my-xdrint " vsync" my-attribute
	+ dup c4 thc!		( vbporch vfporch-1+vsyncw )
	swap dup		( vfporch-1+vsyncw vbporch vbporch)
	my-xdrint " vbporch" my-attribute
	+ dup c8 thc!		( vsyncw+vfporch+vbporch-1 )
	display-height + cc thc!
;


: horz ( hfporch hsyncw hbporch hdisp -- )
	to display-width

	rot dup
	my-xdrint " hfporch" my-attribute
	dup ppc / 1 - dup a0 thc!
	3 pick dup
	my-xdrint " hsync" my-attribute
	ppc / + dup a4 thc!
	rot dup
	my-xdrint " hbporch" my-attribute
	ppc / + dup a8 thc!
	display-width ppc / + dup b0 thc!
	-rot - ppc / - ac thc!
;


: fbc-res ( -- )
	display-width case
	d# 1024 of	ffffe3ff 0 fhc@ and         0 fhc!	endof
	d# 1152 of	ffffe3ff 0 fhc@ and 800 or  0 fhc!	endof
	d# 1280 of	ffffe3ff 0 fhc@ and 1000 or 0 fhc!	endof
	d# 1600 of	ffffe3ff 0 fhc@ and 1800 or 0 fhc!	endof
	d# 1920 of	ffffe3ff 0 fhc@ and 400 or  0 fhc!	endof
	0	to acceleration		\ unknown resolution, no acceleration
	endcase

	\ Handle the 0OFFSET flag.
	cal-tmp @ 4 and 0<> if
		94 thc@  80 or          94 thc!
	else
		94 thc@  80 invert and  94 thc!
	then
;


: cal-tim ( osc hfreq vfreq hfporch hsyncw hbporch hdisp vfporch vsyncw vbporch vdisp flags -- )

	cal-tmp !		\ save flags

	vert		( osc hfreq vfreq hfporch hsync hbporch hdisp )
	horz		( osc hfreq vfreq )
	my-xdrint " vfreq" my-attribute
	my-xdrint " hfreq" my-attribute
			( osc )

	dup my-xdrint " pixfreq" my-attribute

	dup mainosc? cycles-per-tran
	818 thc@ fffffff0 and or 818 thc!

	fbc-res

	bdrev my-xdrint " boardrev" my-attribute
	cal-tmp @ my-xdrint " montype" my-attribute

	acceleration if
		" cgsix"
	else
		" cgthree+"
	then

	my-xdrstring " emulation" my-attribute
;


external

: update-string
   2dup tmp-monitor-string swap move dup tmp-monitor-len !
;

headers


: set-fbconfiguration
	update-string
	parse-line
	cal-tim
;


' set-fbconfiguration to (set-fbconfiguration
' confused? to (confused?


: enable-disables	94 thc@ 800 or         94 thc! ;
: disable-disables	94 thc@ 800 invert and 94 thc! ;


: lego-init-hc
	?fhc-thc-map

	8000 0 fhc!
	1bb 0 fhc!

	chip-rev case
	5 of
		enable-disables
		0 fhc@ 10000 or 0 fhc!
		disable-disables
	endof
	6 of
		enable-disables
		0 fhc@ 10000 or 0 fhc!
		disable-disables
	endof
	7 of
		enable-disables
		0 fhc@ 10000 or 0 fhc!
		disable-disables
	endof
	8 of
		enable-disables
		0 fhc@ 10000 or 0 fhc!
		disable-disables
	endof
		enable-disables
		0 fhc@ 10000 or 0 fhc!
		disable-disables
	endcase

	ffe0ffe0 8fc thc!

	lego-sync-reset
	lego-sync-on

	?fhc-thc-unmap
;


\ Read 4 bytes (MSB first) and form an integer.
: logo@ ( addr -- int )
	0 swap
	4 0 do
		dup c@
		rot
		8 lshift +
		swap 1 +
	loop
	drop
;


: cg6-move-line ( n src dst -- n src dst )
	3dup rot	( n src dst src dst n )
	move		( n src dst )
;


: move-image-to-fb ( w h src dst -- )
	rot 0 do
		( w src dst )
		cg6-move-line
		display-width +
		swap 2 pick + swap
		( w src+w dst+display-width )
	loop
	3drop		( -- )
;


: lego-draw-logo ( line# laddr lwidth lheight -- )

	2 pick 92 +	( line# laddr lwidth lheight laddr+92 )
	logo@				\ read the 4 bytes from laddr+92

	bfdfdfe7 <> if			\ see if they are the magic number
		fb8-draw-logo
	else
		dac-map
		300 logo-data 2 + color	\ set palette from logo-data+2
		dac-unmap

		3drop			( line# )
		logo-data c@		( line# logo-data[0] )
		logo-data 1 + c@	( line# logo-data[0] logo-data[1] )
		rot			( logo-data[0] logo-data[1] line# )

		logo-data 302 + swap char-height * window-top + display-width * window-left + fb-addr +

		move-image-to-fb
	then
;


: diagnostic-type ( stradr strlen -- )
	diagnostic-mode? if
		type cr
	else
		2drop
	then
;


: ?lego-error ( value expected regstradr regstrlen -- )
	2swap <> if		\ value != expexted
		2 to lego-status
		diagnostic-type
		"  r/w failed"
	else			\ value == expected
		2drop
	then
;


: lego-register-test
	selftest-map if
		fb-map
		fbc-map
	then

	8 fbc@
	35 100 fbc!
	ca 104 fbc!
	12345678 110 fbc!
	96969696 84 fbc!
	69696969 80 fbc!
	3c3c3c3c 90 fbc!
	a980cccc 108 fbc!
	ff 10c fbc!
	0 e0 fbc!
	h# 0 e4 fbc!
	display-width 1 - f0 fbc!
	display-height 1 - f4 fbc!
	14aac0 4 fbc!
	h# 0 8 fbc!
	h# 0 4 tec!

	"  FBC register test" diagnostic-type

	100 fbc@
	35		" FBC_FCOLOR"		?lego-error 104 fbc@
	ca		" FBC_BCOLOR"		?lego-error 110 fbc@
	12345678	" FBC_PIXELMASK"	?lego-error 84 fbc@
	96969696	" FBC_Y0"		?lego-error 80 fbc@
	69696969	" FBC_X0"		?lego-error 90 fbc@
	3c3c3c3c	" FBC_RASTEROP"		?lego-error ff 110 fbc!
	0 84 fbc!
	0 80 fbc!
	1f 90 fbc!
	55555555 1c fbc!
	8 fbc!

	selftest-map if
		fb-unmap
		fbc-unmap
	then
;


: lego-fbc-test
	selftest-map if
		fb-map
	then

	"  Font test" diagnostic-type

	8 0 do
		i 4 * fb-addr + @
		ff00ff <> if
			1 to lego-status
			" Fonting to DFB error" diagnostic-type
		then
	loop

	selftest-map if
		fb-unmap
	then
;


: lego-fb-test
	selftest-map if
		fb-map
	then

	ffffffff mask !

	0 group-code !
	fb-addr /frame

	memory-test-suite if
		1 to lego-status
	then

	selftest-map if
		fb-unmap
	then
;


: lego-selftest
	fbc-adr -1 = if
		-1 to selftest-map
	else
		0 to selftest-map
	then

	" Testing cgsix" diagnostic-type

	lego-register-test
	lego-fbc-test
	lego-fb-test
	lego-status
;


: lego-blink-screen lego-video-off 20 ms lego-video-on ;


external

: set-resolution
	$find if
		execute
	then

	lego-init-hc
	(set-fbconfiguration

	(confused? @ if
		sense-code
		(set-fbconfiguration
	then

	my-reset 0 = if

		display-width dup dup
		encode-int " width" property
		encode-int " linebytes" property
		encode-int " awidth" property

		display-height encode-int " height" property

		8 encode-int " depth" property

		/vmsize encode-int " vmsize" property

		display-width display-height * 100000 <= if
			/vmsize 2 = if
				1 to dblbuf?
			else
				0 to dblbuf?
			then
		else
			0 to dblbuf?
		then

		dblbuf? encode-int " dblbuf" property
	then
; \ set-resolution


: set-resolution-ext
	$find if
		execute
	then
	-1 to my-reset
	lego-init-hc
	(set-fbconfiguration
	(confused?
	@ if
		sense-code
		(set-fbconfiguration
	then

	display-width display-height * 100000 <= if
		/vmsize 2 = if
			1 to dblbuf?
		else
			0 to dblbuf?
		then
	else
		0 to dblbuf?
	then

	0 to my-reset

	display-width data-space l!
	display-height data-space 4 + l!

	8 data-space 8 + l!
	display-width data-space c + l!

	dblbuf?

	data-space 10 + l!
	acceleration
	data-space 14 + l!
;


: override ( straddr strlen sensecode -- )
	sense-id-value = if
		set-resolution
	else
		2drop
	then
;


headers


: lego-reset-screen
	-1 to my-reset
	strap-value 94 thc!
	monitor-string set-resolution
	lego-video-on
	0 to my-reset
;


: lego-draw-char		fbc-busy-wait fb8-draw-character ;
: lego-toggle-cursor		fbc-busy-wait fb8-toggle-cursor ;
: lego-invert-screen		fbc-busy-wait fb8-invert-screen ;
: lego-insert-characters	fbc-busy-wait fb8-insert-characters ;
: lego-delete-characters	fbc-busy-wait fb8-delete-characters ;
: dfb-delete-lines		fbc-busy-wait fb8-delete-lines ;
: dfb-insert-lines		fbc-busy-wait fb8-insert-lines ;
: dfb-erase-screen		fbc-busy-wait fb8-erase-screen ;


external

: reinstall-console
	display-width display-height
	over char-width /
	over char-height /
	fb8-install
	['] lego-draw-logo to draw-logo
	['] lego-blink-screen to blink-screen
	['] lego-reset-screen to reset-screen
	['] lego-draw-char to draw-character
	['] lego-toggle-cursor to toggle-cursor
	['] lego-invert-screen to invert-screen
	['] lego-insert-characters to insert-characters
	['] lego-delete-characters to delete-characters
	acceleration if
		['] lego-delete-lines to delete-lines
		['] lego-insert-lines to insert-lines
		['] lego-erase-screen to erase-screen
	else
		['] dfb-delete-lines to delete-lines
		['] dfb-insert-lines to insert-lines
		['] dfb-erase-screen to erase-screen
	then
;

headers


: get-size
	1234567 fb-addr l! 87654321 100000 fb-addr + l! fb-addr
	l@ 1234567 <> if
		1
	else
		fb-addr 100000 + l@ 87654321 <> if
			1
		else
			2
		then
	then
;


: init-duplo
	200000 to /frame
	1239 94 thc! fb-map
	get-size
	fb-unmap
	case
	1 of
		1 to /vmsize
		100000 to /frame
		0 to dblbuf?
		89 to bdrev
		['] legosr-sense to sense-code
	endof
      	2 of
		2 to /vmsize
		1 to dblbuf?
		strap-value 1 or to strap-value
		91 to bdrev
		['] duplosr-sense to sense-code
	endof
	endcase
;


: lego-install
	fb-map
	init-blit-reg
	default-font set-font
	fb-addr encode-int " address" property
	fb-addr to frame-buffer-adr
	my-args dup 0<> if
		set-resolution
	else
		2drop
	then
	reinstall-console
	lego-video-on
;


: lego-remove
	lego-video-off
	fb-unmap
	-1 to frame-buffer-adr
;


: legoh-probe
	my-address legosc-address !

	fhc-thc-map

	init-duplo

	fbc-map
	alt-map

	strap-value

	94 thc!
	fhc @ dup 18 rshift f and 7 swap - to sense-id-value
	14 rshift f and dup encode-int " chiprev" my-attribute to chip-rev

	\ These are 32 dummy writes to ICS register 0 so the new programming
	\ becomes effective.  See my comments in setup-oscillator !
	20 0 do
		\ together this is:  0 0 icswrite
		0 0 alt!
		0800.0000 0 alt!
	loop

	\ VESA_1600x1200x60
	" 74250000,64125000,162000000,135000000," encode-bytes
	\ " 74250000,64125000,216000000,135000000," encode-bytes
	" 118125000,108000000,94500000,54000000," encode-bytes encode+
	" 47250000,81000000,84375000" encode-string encode+ encode-string
	" oscillators" my-attribute

	data-space encode-int " global-data" property
	/frame encode-int " fbmapped" property

	strap-value 8 and
	dup to ppc
	0= if
		4 to ppc
	then

	sense-code set-resolution

	lego-init-dac

	my-address my-space 1000000 reg

	5 0 intr

	['] lego-install is-install
	['] lego-remove is-remove
	['] lego-selftest is-selftest
;

legoh-probe

end0

