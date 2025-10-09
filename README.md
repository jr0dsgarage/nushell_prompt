# j__r0d's custom [nushell](https://www.nushell.sh/) prompt

<img width="1131" height="567" alt="Screenshot 2025-10-09 at 12 24 50 PM" src="https://github.com/user-attachments/assets/73aed40b-3c3f-401e-b3f5-ca21096d8b51" />


## Installation 
- Download the prompt.nu and the themes directory, and place it anywhere, I suggest putting it in the main nushell config directory, next to config.nu.
- source the file in your config.nu:
  - ```nu
     source $"($nu.default-config-dir)/prompt.nu"
    ```
- If using a different theme, be sure to update the top line of `prompt.nu` to reflect the desired theme name.
  - For now this only work with [catppuccin themes](https://github.com/catppuccin/nushell)

