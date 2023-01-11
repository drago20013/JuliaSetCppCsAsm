.data
AlphaMask dd 3 dup (0ffffffffh), 0, 3 dup (0ffffffffh), 0
NotAlphaMask dd 3 dup (0), 0ffffffffh, 3 dup (0), 0ffffffffh
AAMask dd 4 dup(0ffffffffh, 0)
BBMask dd 4 dup(0, 0ffffffffh)
AbsMask dd 8 dup(07fffffffh)
WasSet dd 8 dup(-1)
Ones real4 8 dup(1.0)
Threashold real4 2 dup(0.0, 0.0, 16.0, 16.0)
Twos real4 8 dup(2.0)
ActualIterations dq 4 dup(0)
MaxBrightness real4 8 dup(255.0)
.code
 ;CalculateMandelbrotASM
 ;ComplexCoord* inCoord,	RCX
 ;Pixel* outBMP,			RDX
 ;Settings settings,		R8 
							;c_r 
							;c_i +4
							;size +8
							;maxIter +12
JuliaAsm proc
	mov r9d, dword ptr[r8+8] ; storing size
	shr r9d, 2 ; dividing it by 4 bcuz we process 4 cordinates at the time, this becomes our main counter
	mov r11d, dword ptr[r8+12] ; storing maxIterations, internal loop counter
	vmovq  xmm10, r11
	vpinsrq xmm10, xmm10, r11, 1
	vinserti128 ymm10, ymm10, xmm10, 1
	vmovapd ymm7, ymm10 ;ymm7 = maxIterations
	mov r10, qword ptr[r8] ; Storing C number 
	vmovq  xmm10, r10
	vpinsrq xmm10, xmm10, r10, 1
	vinserti128 ymm10, ymm10, xmm10, 1 ; after broadcasting we have 4 copies of (c_real, c_imag) in ymm10
	vmovaps	ymm8, [AbsMask]; ymm8 = AbsMask
	vmovaps ymm9, [Threashold]; ymm9 = Threashold
	vmovaps	ymm11, [AAMask]; ymm11 = AAMask 
	vmovaps	ymm12, [BBMask]; ymm12 = BBMask 
	vmovaps	ymm13, [Twos]; ymm13 = Twos 
	vmovaps	ymm14, [AlphaMask]; ymm14 = AlphaMask 
	vmovaps	ymm15, [NotAlphaMask]; ymm15 = NotAlphaMask 
	 

MainLoop:
	vmovups	ymm0, ymmword ptr[rcx]
	
	xor r10, r10 ; current iterations 

	mov rax, -1 
	vmovq xmm2, rax
	vpbroadcastq ymm2, xmm2
	vmovaps [WasSet], ymm2
	mov rax, 0
	vmovq xmm2,  rax
	vpbroadcastq ymm2, xmm2
	vmovapd [ActualIterations], ymm2
IterLoop:
	;mov r10d, r8d ; to calculate actual iterations

	vmulps ymm3, ymm0, ymm0 ;a*a and b*b

	vandps ymm2, ymm3, ymm11 ; get a*a
	vandps ymm4, ymm3, ymm12 ; get b*b

	vpshufd ymm2, ymm2, 93h

	vsubps ymm2, ymm2, ymm4 ;get newReal = a*a - b*b
	
	;newImag = 2*a*b
	vandps ymm3, ymm0, ymm12 ; get b
	vandps ymm4, ymm0, ymm11 ; get a

	vpshufd ymm4, ymm4, 93h

	vmulps ymm6, ymm3, ymm4 ;a*b
	vmulps ymm6, ymm6, ymm13 ; newImag = 2*a*b

	;merge aa and bb to ymm2
	vpshufd ymm2, ymm2, 39h
	vorps ymm2, ymm2, ymm6

	;Z = (aa+bb*i) + (ca+cb*i)
	vaddps ymm0, ymm10, ymm2

	;if (Math.Abs(inComplexCoord[i].x + inComplexCoord[i].y) > 16)
	;a - ymm4
	;b - ymm3
	vhaddps ymm3, ymm0, ymm0; inComplexCoord[i].x + inComplexCoord[i].y
	
	vandps ymm3, ymm3, ymm8; Abs
	
	;if larger break and save number of iterations--------
	
	vcmpgtps ymm3, ymm3, ymm9

	vpshufd ymm3, ymm3, 00110110b
	vmovd xmm2, r10d
	vpbroadcastq ymm2, xmm2
	vmovapd ymm4, [ActualIterations] ; previous values
	vandps ymm2, ymm2, ymm3                           
	vandps ymm2, ymm2, [WasSet]                            
	vorpd ymm2, ymm2, ymm4 ;                     

	vmovapd [ActualIterations], ymm2
;==================================
	pextrd eax, xmm3, 0
	mov rsi, -1
	cmp eax, 0 ; Set first one when greater than threashold
	je NotSet1
	mov rsi, 0

NotSet1:
	pinsrq xmm2, rsi, 0

	pextrd eax, xmm3, 2
	mov rsi, -1
	cmp eax, 0 ;; Set second one when greater than threashold
	je NotSet2
	mov rsi, 0

NotSet2:
	pinsrq xmm2, rsi, 1

	vextracti128 xmm4, ymm3, 1
	 
	pextrd eax, xmm4, 0
	mov rsi, -1
	cmp eax, 0 ;; Set third one when greater than threashold
	je NotSet3
	mov rsi, 0

NotSet3:
	pinsrq xmm5, rsi, 0

	pextrd eax, xmm4, 2 
	mov rsi, -1
	cmp eax, 0 ;; Set fourth one when greater than threashold
	je NotSet4
	mov rsi, 0

NotSet4:
	pinsrq xmm5, rsi, 1

	vinserti128 ymm2, ymm2, xmm5, 1; merge xmm2 and xmm5 to ymm2, which creates was set mask
	vmovaps [WasSet], ymm2

	vhaddpd ymm2, ymm2, ymm2 
	pextrq rax, xmm2, 0
	vextracti128 xmm2, ymm2, 1
	pextrq rsi, xmm2, 0
	add rax, rsi
	cmp rax, 0
	je IterLoop_esc

	;xmm2 1 0
	;xmm5 3 2
	;check if all were set, if yes jump(actually just move further) out to _esc

	inc r10d
	cmp r10d, r11d
	jl IterLoop

IterLoop_esc:

	;=======================================================
	;Coloring

	vmovapd ymm2, [ActualIterations] ; n 0 n 0 n 0 n 0
	;;;;;;;;;;;;;vcvtdq2ps ymm2, ymm2
	;STEP 1: Remap actual iterations from 0-MaxTterations to 0-1 floating point
	;ymm2 = toLow + (ymm2 - fromLow) * (toHigh - toLow) / (fromHigh - fromLow)

	;(ymm2 - fromLow) = ymm2
	;vxorpd ymm0, ymm0, ymm0; ymm0 = 0 - > fromLow		;
	;vsubpd ymm2, ymm2, ymm0; ymm2 = values - fromLow	; In our case always value - 0 so skipping these steps

	;(toHigh - toLow) = ymm3
	;vmovapd ymm3, ymmword [Ones]; ymm3 = 1.0 -> toHigh	;
	;vsubpd ymm3, ymm3, ymm0							; again 1 - 0 is 1 always

	;(ymm2 - fromLow) * (toHigh - toLow) = ymm2
	;vmulpd	ymm2, ymm2, ymm3; and once again 5*1 is 5 so skipping

	;(fromHigh - fromLow), ymm7 -> maxIter -> fromHigh, fromLow=0 so useless
	;(ymm2 - fromLow) * (toHigh - toLow) / (fromHigh - fromLow)
	vdivps ymm2, ymm2, ymm7

	;lastly add toLow to ymm2, but toLow is 0 so useless
	;now in ymm2 should be the values mapped from 0->maxIter to 0->1

	;STEP 2: Take sqrt of these values

	vsqrtps ymm2, ymm2

	;STEP 3: Remap values after sqrt from 0-1 to 0-255

	;load MaxBrightness(toHigh) to ymm3, and substract from it toLow, but its 0 so again result is MaxBrightness
	vmovaps ymm3, [MaxBrightness]
	
	;(ymm2(values-fromLow) * ymm3(toHigh - toLow) = ymm2
	vmulps	ymm2, ymm2, ymm3

	;(ymm2 - fromLow) * (toHigh - toLow) / (fromHigh - fromLow), fromHigh is [Ones], fromLow is 0
	;so its ymm2 / [Ones] and anything divided by 1 is itself so skipping this step
	
	;lastly add toLow to ymm2, but toLow is 0 so useless
	;now in ymm2 should be the values mapped from 0->1 to 0->255
	;Values should be back in the ymm2

	;calculate each part of color and put it back to pixel
	;vmovups	ymm0, ymmword ptr[rdx]
	
	vextractf128 xmm4, ymm2, 0
	;first pixel
	extractps eax, xmm4, 0
	vmovd xmm3, eax
	vbroadcastss xmm3, xmm3
	;second
	extractps eax, xmm4, 2
	vmovd xmm4, eax
	vbroadcastss xmm4, xmm4

	vinsertf128 ymm3, ymm3, xmm4, 1

	vmovupd ymmword ptr[rdx], ymm3 ; save two pixels data and move pointer and load data for next two	
	add rdx, 32

	vextractf128 xmm4, ymm2, 1
	;third
	extractps eax, xmm4, 0
	vmovd xmm3, eax
	vbroadcastss xmm3, xmm3
	;fourth
	extractps eax, xmm4, 2
	vmovd xmm4, eax
	vbroadcastss xmm4, xmm4

	vinsertf128 ymm3, ymm3, xmm4, 1

	vmovupd ymmword ptr[rdx], ymm3

	add rdx, 32
	
	add rcx, 32
	dec r9d
	jnz MainLoop

	ret
JuliaAsm endp
end