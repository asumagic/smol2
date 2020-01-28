; This standalone firmware plays back a 80x25 monochrome @30fps video file.
; Each byte of the included binary video file represents 8 horizontally aligned pixels.
; The LSB of each byte maps to the first character to display in the buffer.
; Each frame being (80x25)/8 bytes, one frame takes up 250 bytes.
;
; e.g. in ASCII the following:
; 
;   XXXX____XX__XXXX
;
; would translate to this (binary):
; 
;   0000'1111 1111'0011
;
; The video is included from bank 1, so the video data starts at 0x2000.
; Once reaching the end of a bank, it will skip to the next.

; C pseudocode
;
; #define PALETTE_WHITE 0x11
; #define PALETTE_BLACK 0x00
;
; #define FRAMEBUFFER_START_ADDRESS 0x2001
; #define MMIO_BANK 0xFFFF
;
; #define VIDEO_ROM_START_ADDRESS 0x2000;
; #define VIDEO_ROM_START_BANK 0x0001
;
; void start()
; {
; 	char* rom_ptr = (char*)VIDEO_ROM_START_ADDRESS;
; 	short rom_bank = VIDEO_ROM_START_BANK;
;
; 	const char* framebuffer_stop_address = 0x2FA1;
;
; 	while (true)
; 	{
; 		char* framebuffer_address = FRAMEBUFFER_START_ADDRESS;
;
; 		while (framebuffer_address != framebuffer_stop_address)
; 		{
; 			set_bank(rom_bank);
; 			char char_group = *rom_ptr;
;
; 			set_bank(MMIO_BANK);
;
; 			// 8 chars in one byte of video ROM; 2 bytes per fb char
; 			const char* char_group_stop_address = framebuffer_address + (8 * 2);
;
; 			while (framebuffer_address != char_group_stop_address)
; 			{
; 				bool is_set = (char_group & 0x01) != 0;
;
; 				if (is_set)
; 				{
; 					*framebuffer_address = PALETTE_WHITE;
; 				}
; 				else
; 				{
; 					*framebuffer_address = PALETTE_BLACK;
; 				}
;
; 				char_group = char_group >> 1;
;
; 				framebuffer_address += 2;
; 			}
;
; 			rom_ptr += 1;
;
; 			// Overflow
; 			if (rom_ptr == 0)
; 			{
; 				rom_ptr = VIDEO_ROM_START_ADDRESS;
; 				rom_bank += 1;
; 			}
; 		}
; 	}
;
;   wait_vsync();
; }

; char* rom_ptr = (char*)VIDEO_ROM_START_ADDRESS;
liu $g0 0x20
li $g0 0x00

; short rom_bank = VIDEO_ROM_START_BANK;
liu $g1 0x00
li $g1 0x01

; const char* framebuffer_stop_address = 0x2FA1;
liu $g2 0x2F
li $g2 0xA1

; while(true)
prepareframe:
	; char* framebuffer_address = FRAMEBUFFER_START_ADDRESS;
    liu $g3 0x20
	li $g3 0x01

	; while (framebuffer_address != framebuffer_stop_address)
	drawframe:
		; set_bank(rom_bank);
		or $bank $g1 $g1

		; char char_group = *rom_ptr;
		lm $g0 $g4

		; set_bank(MMIO_BANK);
        liu $bank 0xFF
        li $bank 0xFF

		; const char* char_group_stop_address = framebuffer_address + (8 * 2);
		xor $g13 $g13 $g13
		li $g13 16 ; tmp = 16
		add $g5 $g3 $g13
		; $g13 freed

		; while (framebuffer_address != char_group_stop_address)
		drawpixelgroup:
			; bool is_set = (char_group & 0x01) != 0;
			xor $g13 $g13 $g13
			li $g13 1 ; tmp = 0x01
			and $g6 $g4 $g13
			; $g13 freed

			; if (is_set)
			li $g13 setwhite ; FIXME: upper bits
			bnz $g13 $g6
			; $g13 freed
			setblack:
				; *framebuffer_address = PALETTE_BLACK;
				xor $g13 $g13 $g13 ; tmp = 0x00
				sm $g3 $g13
				; $g13 freed

				; (handle branching)
				li $g13 setcolorend
                or $ip $g13 $g13
				; $g13 freed

			setwhite:
				; *framebuffer_address = PALETTE_BLACK;
				xor $g13 $g13 $g13
				li $g13 17 ; tmp = 0x11
				sm $g3 $g13
				; $g13 freed
				
				; fallthrough

			setcolorend:
			; char_group = char_group >> 1;
			xor $g13 $g13 $g13
			li $g13 1 ; tmp = 1
			shr $g4 $g4 $g13
			; $g13 freed

			; framebuffer_address += 2;
			xor $g13 $g13 $g13
			li $g13 2 ; tmp = 2
			add $g3 $g3 $g13
			; $g13 freed

			; (handle looping)
			; while (framebuffer_address != char_group_stop_address)
			xor $g12 $g12 $g12
			li $g12 drawpixelgroup ; FIXME: upper bits
			sub $g13 $g3 $g5
			bnz $g12 $g13
			; $g12, $g13 freed

			; fallthrough

		; rom_ptr += 1;
		xor $g13 $g13 $g13
		li $g13 1 ; tmp = 1
		add $g0 $g0 $g13
		; $g13 freed

		; if (rom_ptr == 0)
		; => if (rom_ptr != 0) skip
		xor $g13 $g13 $g13 ; FIXME: upper bits
		li $g13 skipbankswitch
		bnz $g13 $g0
		; $g13 freed

			; rom_ptr = VIDEO_ROM_START_ADDRESS;
            liu $g0 0x20
            li $g0 0x00

			; rom_bank += 1;
			xor $g13 $g13 $g13
			li $g13 1
			add $g1 $g1 $g13
		skipbankswitch:

		; (handle looping)
		; while (framebuffer_address != framebuffer_stop_address)
		xor $g12 $g12 $g12
		li $g12 drawframe
		sub $g13 $g3 $g2
		bnz $g12 $g13
		; $g12, $g13 freed

		; fallthrough

	; wait_vsync();
    liu $g13 0x2F
	li $g13 0xD0
	sm $g13 $g13 ; the byte we write has no importance

	; (handle looping)
	; while (true)
	xor $g13 $g13 $g13
	li $g13 prepareframe ; FIXME: upper bits
    or $ip $g13 $g13
	; $g13 freed

; Include the binary video file
@0x2000
#./assets/badapple.bin