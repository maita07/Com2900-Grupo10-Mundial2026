/*
================================================================================
UNLaM - Base de Datos Aplicada (Comisión 5600)
Entrega 7 - Reporte 7: Resultados de los Encuentros (Formato XML / Tabular)
2026 - 2C
Grupo 10

Integrantes:
- Monasterio Erik: MonasteryEr
- Arena Ariel Ignacio: arielarena
- Castillo Gabriela Florencia: ItsFlorencia
- Maita Pitado Jose Gregorio: maita07

Archivo: 06_1_CIFRADO.sql
Descripcion:
- Stored Procedure que cifra la fecha de nacimiento, peso y altura de las personas y jugadores.
- Usa AES256 ya que permite descifrar para leer dicho dato. Con sha256 no se puede.
- No ciframos otros datos debido a que se llaman o utilizan regularmente, como el dni como PK.
================================================================================
*/
USE DB_Mundial2026_Grupo10;
GO

