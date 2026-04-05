| Layer          | MAC Count   | Parameter Count |
|----------------|-------------|-----------------|
| conv1          | 118,013,952 | 9,408           |
| layer1.0.conv1 | 115,605,504 | 36,864          |
| layer1.0.conv2 | 115,605,504 | 36,864          |
| layer1.1.conv1 | 115,605,504 | 36,864          |
| layer1.1.conv2 | 115,605,504 | 36,864          |

Arithmetic Intensity(conv1) = (2 x MACs) / (weight bytes + activation bytes)

weight bytes = 4 x 9,408 = 37,632 bytes

activation bytes = 1 x 3 x 224 x 224 x 4 = 602,112 bytes


Arithmetic Intensity(conv1) = (2 x 118,013,952) / (37,632 + 602,112)

Arithmetic Intensity(conv1) = 236,027,904 / 639,744

Arithmetic Intensity(conv1) = 368.94
