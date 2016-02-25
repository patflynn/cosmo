(scroll-bar-mode -1)
(setq prelude-whitespace nil)
(prelude-require-packages '(ujelly-theme))

(global-set-key "\C-w" 'backward-kill-word)
(global-set-key "\C-x\C-k" 'kill-region)
(global-set-key "\C-c\C-k" 'kill-region)
