const XLSX = require('xlsx');

const file = 'C:\\Users\\Administrador\\Downloads\\Horario Secundario Marzo 2026.xlsx';
const workbook = XLSX.readFile(file);
const sheet = workbook.Sheets['2026'];
const data = XLSX.utils.sheet_to_json(sheet, { header: 1 });

console.log("=== 1° SEC schedule rows ===");
for (let i = 0; i < 14; i++) {
  console.log(`Row ${i + 1}:`, data[i] ? data[i].slice(0, 6) : []);
}
