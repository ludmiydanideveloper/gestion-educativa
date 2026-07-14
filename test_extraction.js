const XLSX = require('xlsx');

const file = 'C:\\Users\\Administrador\\Downloads\\Horario Secundario Marzo 2026.xlsx';
const workbook = XLSX.readFile(file);

const courses = [];

workbook.SheetNames.forEach(sheetName => {
  const sheet = workbook.Sheets[sheetName];
  const data = XLSX.utils.sheet_to_json(sheet, { header: 1 });
  
  for (let r = 0; r < data.length; r++) {
    const row = data[r];
    if (!row) continue;
    for (let c = 0; c < row.length; c++) {
      const val = row[c];
      if (val && typeof val === 'string' && val.includes('HORARIO')) {
        const match = val.match(/HORARIO\s+([^-\(]+)/i);
        const name = match ? match[1].trim() : val;
        
        // Extract schedule entries for this block
        const entries = [];
        const subjects = new Set();
        
        let currRow = r + 2;
        while (currRow < data.length) {
          const sRow = data[currRow];
          if (!sRow) break;
          const horaVal = sRow[c];
          
          // Stop if we hit a new course header or empty row
          if (horaVal && typeof horaVal === 'string' && horaVal.includes('HORARIO')) {
            break;
          }
          if (horaVal === undefined || horaVal === null || String(horaVal).trim() === '') {
            // Check if entire row of this block is empty
            let blockEmpty = true;
            for (let offset = 0; offset < 6; offset++) {
              if (sRow[c + offset] !== undefined && sRow[c + offset] !== null && String(sRow[c + offset]).trim() !== '') {
                blockEmpty = false;
              }
            }
            if (blockEmpty) break;
          }
          
          const horaStr = String(horaVal || '').trim();
          if (horaStr && !horaStr.toLowerCase().includes('recreo')) {
            // Loop through Lunes (1) to Viernes (5)
            const days = ['LUNES', 'MARTES', 'MIÉRCOLES', 'JUEVES', 'VIERNES'];
            for (let d = 1; d <= 5; d++) {
              const subject = sRow[c + d];
              if (subject && String(subject).trim() !== '') {
                const subName = String(subject).trim();
                subjects.add(subName);
                entries.push({
                  day: days[d - 1],
                  time: horaStr,
                  subject: subName
                });
              }
            }
          }
          currRow++;
        }
        
        courses.push({
          courseName: name,
          sheetName: sheetName,
          subjects: Array.from(subjects),
          entries: entries
        });
      }
    }
  }
});

console.log("Extraction results for the first course (1° SEC):");
console.log(courses[0]);
console.log("\nTotal courses found:", courses.length);
