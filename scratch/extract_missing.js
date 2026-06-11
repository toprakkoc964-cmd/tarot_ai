const fs = require('fs');
const path = require('path');

const localesDir = path.join(__dirname, '..', 'assets', 'locales');
const en = JSON.parse(fs.readFileSync(path.join(localesDir, 'en.json'), 'utf8'));

['de', 'fr', 'es'].forEach(lang => {
  const file = path.join(localesDir, `${lang}.json`);
  const data = JSON.parse(fs.readFileSync(file, 'utf8'));
  const missing = {};
  
  Object.keys(en).forEach(k => {
    if (!data.hasOwnProperty(k)) {
      missing[k] = en[k];
    }
  });
  
  fs.writeFileSync(
    path.join(__dirname, `${lang}_missing.json`),
    JSON.stringify(missing, null, 2),
    'utf8'
  );
  console.log(`${lang} missing keys written to ${lang}_missing.json: ${Object.keys(missing).length} keys`);
});
