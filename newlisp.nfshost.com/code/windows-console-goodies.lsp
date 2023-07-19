        #
        #  module for Win32-console
        #
        # modernized 5/31/2017 by caveguy and tested
        # using newLISP v.10.7.1 64-bit on Windows
        #

        (context 'CONSOLE)

        (import "kernel32.DLL" "GetStdHandle")
        (import "kernel32.DLL" "SetConsoleTextAttribute")
        (import "kernel32.DLL" "SetConsoleCursorPosition" )
        (import "kernel32.DLL" "GetConsoleScreenBufferInfo" )
        (import "kernel32.DLL" "ReadConsoleOutputCharacterA" )
        (import "kernel32.DLL" "ReadConsoleOutputAttribute" )
        (import "kernel32.DLL" "SetConsoleCursorInfo" )
        (import "kernel32.DLL" "GetConsoleCursorInfo" )
        (import "msvcrt.DLL"   "_kbhit" )


        (constant 'STD_OUTPUT_HANDLE 0xfffffff5)

        (setq colors (transpose   (list (map term
          '(BLA BLU GRE CYA RED MAG YEL WHI LBLA LBLU LGRE
            LCYA LRED LMAG LYEL LWHI))
            (sequence 0 15 ))))

        (define (cons-output-handle)
          (GetStdHandle STD_OUTPUT_HANDLE))

        ;  Get a string of characters from the screen.
        (define (get-text x y num , buffer num-read)
          (setq buffer (dup " " num))
          (setq num-read (dup " " 4))
          (if (= 0 (ReadConsoleOutputCharacterA (cons-output-handle)
                    buffer num (+ x (<< y 16)) num-read))
              nil
              (slice buffer 0 (first (unpack "lu" num-read)))))

        ;  Get a list of console attributes (colors).
        (define (get-attributes x y num , buffer num-read)
          (setq buffer (dup " " (* 2 num))) # 2 bytes per cell
          (setq num-read (dup " " 4))
          (if (= 0 (ReadConsoleOutputAttribute (cons-output-handle)
                buffer num (+ x (<< y 16)) num-read))
              nil
              (map (fn (n) (& n 0xff))
                (unpack (dup "u" (first (unpack "lu" num-read))) buffer))))


        (define (set-attribute attr)
          (< 0 (SetConsoleTextAttribute (cons-output-handle) attr)))


        ;;  Returns (cursor-height(1--100%) visible)
        (define (get-cursor-info , buffer)
          (setq buffer (dup " " 5))
          (if (= 0 (GetConsoleCursorInfo (cons-output-handle) buffer))
            nil
            (unpack  "lu c" buffer)))

        (define (hide-cursor , buffer)
          (setq buffer (pack "lu c" (first (get-cursor-info)) 0))
          (< 0 (SetConsoleCursorInfo (cons-output-handle) buffer)))

        (define (show-cursor , buffer)
          (setq buffer (pack "lu c" (first (get-cursor-info)) -1))
          (< 0 (SetConsoleCursorInfo (cons-output-handle) buffer)))

        ;;  Height is percent (1--100).
        (define (set-cursor-height height , buffer)
          (setq buffer (pack "lu c" height (last (get-cursor-info))))
          (< 0 (SetConsoleCursorInfo (cons-output-handle) buffer)))


        (define (set-cursor-position position)
          (< 0 (SetConsoleCursorPosition
                  (cons-output-handle) position)))


        (define (at-xy x y)
          (setq x (max x 0))
          (setq y (max y 0))
          (set-cursor-position (| (<< y 16) x) ))


        (define (get-console-info , buffer)
          (setq buffer (dup " " 22))
          (if (= 0 (GetConsoleScreenBufferInfo (cons-output-handle) buffer))
            nil
            (unpack  "uuuuudddduu" buffer)))

        ;  Get the attribute that is currently used when writing.
        (define (get-current-attribute)
          (& 0xff ((get-console-info) 4)))


        ; Make sure that 0 <= x <= 15.
        (define (clamp x)
          (int (max 0 (min 15 x))))

        ; Arguments can be strings or integers.
        ; Default arguments:  7  0
        (define (console-colors foreground background)
          (setq foreground (or foreground 7))
          (setq background (or background 0))
          (setq foreground (or (lookup foreground colors)
            (clamp foreground)))
          (setq background (or (lookup background colors)
            (clamp background)))
          (set-attribute (| (<< background 4) foreground)))


        ;;  ----  Back to MAIN context.  ----

        (context 'MAIN)

        (define (key-pressed?)
          (!= 0 (CONSOLE:_kbhit)))

        ;; (width height)
        (define (get-console-size)
          (slice (CONSOLE:get-console-info) 0 2))


        ; Arguments can be symbols, strings, or integers.
        ; Examples: (console-colors 7 0)
        ;           (console-colors 'LYEL 'LBLA)
        ;           (console-colors "LMAG" "BLA")
        (define (console-colors foreground background)
          (if (symbol? foreground)
            (setq foreground (term foreground)))
          (if (symbol? background)
            (setq background (term background)))
          (CONSOLE:console-colors
            foreground background))

        ;; Get cursor position.  Upper left is (0 0).
        (define (get-xy)
          (slice (CONSOLE:get-console-info) 2 2))

        ;; Move cursor.
        (define (at-xy x y) (CONSOLE:at-xy x y))

        (define (cls , width height i)
          (map set '(width height) (get-console-size))
          (at-xy 0 0)
          (dotimes (i height)
            (print (dup " " width)))
          (at-xy 0 0))



        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;  Test code
        ;;  To make this run, invoke in this manner:
        ;;  newlisp w32cons.lsp test
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        (if (and (= "test" (last (main-args)))
                 (= 3 (length (main-args))) )
        (begin

          (set 'old-attr (CONSOLE:get-current-attribute))
          (console-colors)
          (cls)
          (CONSOLE:hide-cursor)

          ;;  To test the clamping, we make the background
          ;;  color range from -1 to 16 instead of from
          ;;  0 to 15.
          (for (back -1 16)
            (at-xy 0 (+ 1 back))
            (dotimes (fore 16)
              (console-colors fore back)   
              (print (format "%02d@%02d" fore back))))
          (console-colors)
          (println)

          (print "Press a key.")
          (setq coords '(10 27 0 17))
          (setq mappings '((0 2) (1 2) (0 3) (1 3)))
          (setq deltas '(1 -1 1 -1))
          (setq chars (map char '(6 5 4 3)))
          (setq span 4)
          (do-until (key-pressed?)
            (setq texts '())   (setq colors '())
            (dotimes (i 4)
              (map set '(x y) (select coords ( mappings i)))
              (push  (CONSOLE:get-text x y span) texts -1)
              (push (CONSOLE:get-attributes x y span) colors -1)
              (console-colors (if (> i 1) "LRED" "BLA") "LWHI")
              (at-xy x y) (print (dup (chars i) span)))
            (sleep 400)
            (dotimes (i 4)
              (map set '(x y) (select coords ( mappings i)))
              (at-xy x y)
              (setq text (texts i))
              (dotimes (j span) (CONSOLE:set-attribute ((colors i)j))
                (print (text j))))
            (setq coords (map + coords deltas))
            (if (or (= (last coords) 0) (> (last coords) 16))
              (rotate deltas))
          )
          (read-key)
          (CONSOLE:set-attribute old-attr)
          (cls)
          (CONSOLE:show-cursor)
          (exit)
        ))


