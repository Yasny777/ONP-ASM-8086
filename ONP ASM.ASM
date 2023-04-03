org 100h

start:
	call compow
	call setInpt
	call toONP
	call dispONP
	call calcONP
	call dispRES
endprog:
	mov	ax, 4Ch
	int	21h

;zmienne
resCom db 10, 13, "Wynik dzialania to: $"
zeroECom db 10, 13, "Wyjatek: Dzielenie przez zero!$"
com db 10, 13, "Podaj wyrazenie w postaci infiksowej (operatory: + - * /)", 10, 13, "(zakres 16 bitowy) (max 25 znakow) (uwzglednia liczby ujemne)", 10, 13, "(brak walidacji) (przyklad: 26*4-76/2): $"
comONP db 10, 13, "W postaci ONP: $"

input	db	26 ; max do wpisania i miejsce na enter
		db	0 ; ilosc znakow bez entera
		times 27 db "$"
outpt  times 60 db 36 ; wiecej miejsca w output bo miejsce na spacje
		
var db 0 ; zmienna aktualnego priorytetu

result dw 0 ; wynik koncowy

liczba dw 0

signF db 0 ; flaga znaku wyniku koncowego

; funkcja wyswietla wynik w postaci decymalnej
dispRES:
	pusha 
	pushf
	; komunikat na ekran
		mov ah, 9
		mov dx, resCom
		int 21h

		cmp [result], byte 0
		jne notZero
		mov ah, 2
		mov dx, 48
		int 21h
		jmp endDISP
		notZero:
		cmp byte [signF], 1
		jne NujmL
			mov ah, 2
			mov dx, 45
			int 21h
		NujmL:
	;zeruje sobie wszystkie rejestry
	xor ax, ax
	xor bx, bx
	xor cx, cx
	xor dx, dx
	;daje do cx 10 decymalna by moc wyswietlac poszczegolne cyfry wyniku
	mov cx, 10
	mov ax, [result] ; do ax daje nasz wynik
		wysw2:
			div cx ; dziele przez 10 wynik i biore reszte
			inc bx; tu zapisuje ile nasz wynik ma znakow (i ile zajmie miejsc na stosie)
			push dx ; daje reszte na stos (ostatnia cyfre)
			xor dx, dx ; zeruje dx czyli reszte
			cmp ax, 0 ; patrze czy wynik dzielenie jest 0 jesli jest to znaczy ze cala liczba zostala juz podzielona
			jne wysw2 ; petla
			mov cx, bx ; przenosze do cx wartosc z bx by miec nowy licznik (tu ilosc cyfr z wyniku na stosie)
			xor dx, dx ; zeruje dx
		wysw3:
			mov ah, 2 
			pop dx ; sciagam cyfre ze stosu
			add dx, 48 ; dodaje 48 ascii przesuniecia by miec znak cyfry
			int 21h
			xor dx, dx ; zeruje dx
			dec cx
			cmp cx, 0
			jne wysw3 ; i tak w kolko az do wyswietlenia wszystkiego
	endDISP:
	popf
	popa
	ret

;funkcja liczy na kooprocesorze wynik onp
calcONP:
	pusha
	pushf
		FINIT ; inicjalizacja kooprocesora
		xor ax, ax
		xor bx, bx
		xor cx, cx
		xor dx, dx


		mov bp, sp ; wskaznik wierzcholka do bp
		mov bx, outpt ; adres zmiennej (dzialania onp) do bx
		

		ONPstack:
			xor ax, ax 
			mov al, byte[bx] ; daje bajt z zmiennej do al i sprawdzam czy to nie $ by przerwac dodawanie na stos
			cmp ax, 36
			je calced ; skacze do konca
			mov dx, ax


			cmp dx, 48
			jb notDig
			cmp dx, 57
			ja notDig

			push dx ; cyfra z liczby na stos
			inc bx
			jmp ONPstack

			digToFPU:
				xor dx, dx ; usuwamy z dx spacje
				cmp bp, sp ; jezeli nic na stosie to po operatorze spacja 
				je pustySt
				mov cx, 1
				digTFlp:
				cmp bp, sp ; jezeli pusty stos to wszystkie cyfry obsluzone i jest liczba
				je LtoFPU
				; zalozmy ze na stosie 356 -> 
				; 3
				; 5
				; 6 <- wierzcholek
				pop ax ; sciagamy cyfre do ax 
				sub ax, 48 ; odejmujemy przesuniecie
				mul cx ; ax * dx -> dx:ax ale 16bitowe wiec wynik w ax
				add [liczba], ax ; dodajemy do liczby ax
				mov ax, cx ; zwiekszamy cx * 10
				mov dx, 10
				mul dx 
				mov cx, ax
				jmp digTFlp

				LtoFPU:
					FILD word [liczba]
					mov [liczba], word 0
					inc bx
					jmp ONPstack

				pustySt:
					inc bx
					jmp ONPstack

			notDig:
				cmp dx, 32 ; sprawdzamy czy spacja 
				je digToFPU
				; tu jak nie cyfra
				; jak nie cyfra to operator
				; switch case dla znaku
				cmp dx, 43 ; dodawanie +
				je dodFPU
				cmp dx, 45 ; odejmowanie ;
				je odejFPU 
				cmp dx, 42 ; mnozenie * 
				je mnozFPU
				cmp dx, 47 ; dzielnie /
				je dzielFPU
				;jezeli juz nie operator to koniec
				jmp calced

				dodFPU:
					; trzeba dodac st1 do st0 i zostawic wynik na stosie
					FADDP st1, st0 ; wynik w st1 wiec sciagamy st0 ze stosu
					inc bx
					jmp ONPstack
				odejFPU:	
					FSUBP st1, st0
					inc bx
					jmp ONPstack
				mnozFPU:
					FMULP st1, st0
					inc bx
					jmp ONPstack
				dzielFPU:
					; sprawdzam czy st0 nie jest zerem
					FLDZ ; ładuje zero
					FCOMP ; porownuje dzielnik z zerem i sciagam zero
					FSTSW ax ; przerzucam flagi do ah 
					SAHF
					je zeroExc
					FDIVP st1, st0
					inc bx
					jmp ONPstack
					zeroExc:
						mov ah, 2
						mov dx, 10
						int 21h
						mov dx, 13
						int 21h
						mov ah, 9
						mov dx, zeroECom
						int 21h
						mov ax, 4Ch
						int 21h
		calced:
		; na st0 wynik
		; laduje zero i je porownuje by ustawic flagi
		FLDZ
		FCOMP
		FSTSW ax
		SAHF
		jnc ujemna ; jesli flaga carry nie jest ustawiona to liczba ujemna
		jmp nieujem
		ujemna:
			FISTP word [result] ; wynik calkowity
			mov ax, word [result]
			xor ax, 0xFFFF ; xoruje przez 16 jedynek
			add ax, 1 ; dodaje 1 bo to u2
			mov [result], ax
			mov [signF], byte 1 ; ustawiam pomocniczna flage znaku na 1
			jmp calced2 
		nieujem:
		FISTP word [result] ; wynik calkowity 
		
		calced2:
	popf
	popa
	ret

; funkcja wyswietlajaca komunikat + wynik ONP
dispONP:
	pusha
	pushf
		mov ah, 9
		mov dx, comONP 
		int 21h

		mov ah,2
		mov dl,10
		int 21h
		mov dl,13
		int 21h

		mov ah, 9
		mov dx, outpt
		int 21h
	popf
	popa
	ret

; funkcja ustawiajaca wartosc wejsciowa
setInpt:
	pusha
	pushf
	;enter
		mov ah,2
		mov dl,10
		int 21h
		mov dl,13
		int 21h
	; wejscie do zmiennej
		mov ah,10
		mov dx,input
		int 21h
	popf
	popa
	ret

; funkcja - komunikat powitalny
compow:
	pusha
	pushf
		mov ah, 9
		mov dx, com
		int 21h
	popf
	popa
	ret
; funkcja zamieniajaca postac infiksowa na ONP
toONP:
	pusha
	pushf
		; czyszczenie rejestrow dla porzadku
		xor ax, ax
		xor bx, bx
		xor cx, cx
		xor dx, dx
		
		mov bp, sp ; wskaznik wierzchołka stosu do bp
		mov si, input+2 ; ustawiam source index na miejsce wczytanych znakow
		mov di, outpt ; direction index na zmienna outpt

		lop:
			xor ax, ax
			cmp bl, byte[input+1] ; ilosc znakow do bl
			je endONP ; jezeli liczba znakow rowna bl to koniec ciagu wejsciowego
			inc bx ; zwiekszam bl za kazdym znakiem nowym
			mov al, byte[input+1+bx] ; znak z klawiatury do al 
			; czy cyfra jezeli tak to na wyjscie
			cmp ax,48
			jb niecyfra
			cmp ax,57
			ja niecyfra
			; jezeli cyfra kopiuj
			mov [si], al
			cld 
			movsb
			jmp lop

		niecyfra: 
			; sprawdza czy ( jezeli tak to na stos
					
			cmp ax,40
			jne nienaw 
			push ax
			jmp lop

		nienaw: 
			; sprawdza czy ) jezeli tak to sciaga ze stosu i daje na wyjscie operatory az do (
			cmp ax,41
			jne nienawzm 

			lop2:
				pop dx
				cmp dx,40
				je nawOtw
				mov [si], byte 32
				cld
				movsb
				dec si ; po movsb sie zwieksza si i di wiec zmniejszam si po wstawieniu spacji
				mov [si], dl
				cld
				movsb
				jmp lop2
			nawOtw:
			jmp lop

		; sprawdzanie operatorow
		nienawzm: 
			mov [si], byte 32
			cld
			movsb
			dec si ; po movsb sie zwieksza si i di wiec zmniejszam si po wstawieniu spacji
			push ax ; aktualny operator na stos
			call setPrio ; sprawdzanie jego priorytetu i ustawienie
			pop ax ; sciaga aktualny operator 
			mov cx, word [var] ; do cx aktualny priorytet
			
			OPlop:
				cmp bp, sp ; porownuje bp z sp jezeli rowne to operator na stos
				jne cmpOP
				push ax
				
				jmp OPexit
				
			; porownuje operator na stosie z aktualnym jezeli na stosie wiekszy to go sciaga na wyjscie i daje na stos aktualny z mniejszym priorytetem
			cmpOP: 
				call setPrio
				cmp cx, word [var]
				jbe OPmnrow
				push ax
				jmp OPexit
				
			OPmnrow:
				pop dx
				push ax
				mov [si], dl
				cld
				movsb
				mov [si], byte 32
				cld
				movsb
				dec si ; po movsb sie zwieksza si i di wiec zmniejszam si po wstawieniu spacji
				pop ax
				jmp OPlop
			OPexit:
			jmp lop
		endONP:
		
		; sciaga na wyjscie pozostale operatory ze stosu ktore zostaly
		zestosu:
			cmp bp,sp
			je stsend
			mov [si], byte 32
			cld
			movsb
			dec si ; po movsb sie zwieksza si i di wiec zmniejszam si po wstawieniu spacji
			pop dx
			mov [si], dl
			cld
			movsb
			jmp zestosu
		stsend:
	popf
	popa
ret

; funkcja ustawia priorytet na dzialanie +-1 */2
setPrio:
	pusha
	pushf
		mov bp, sp ; wskaznik wierzcholka do bp
		mov ax, word [bp + 20] ; bierze operator ze stosu kopiuje do ax
		plus:
			cmp ax,43 
			jne minus
			mov dx, 1
			mov [var], dl
			jmp prioext

		minus:
			cmp ax,45 
			jne mnoz
			mov dx, 1
			mov [var], dl
			jmp prioext

		mnoz:
			cmp ax,42 
			jne dziel
			mov dx, 2
			mov [var], dl
			jmp prioext

		dziel:
			cmp ax,47 
			jne nieop
			mov dx, 2
			mov [var], dl 
			jmp prioext

		nieop:
			mov [var], byte 0
	prioext:
	popf
	popa
ret
