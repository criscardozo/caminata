// Not a secret: a Firebase web config is public by design. These exact values
// are served to every visitor in this file, so hiding them from the repo would
// buy nothing. What actually guards the data is firebase/firestore.rules,
// which allows a signed-in account to touch only its own walks, plus the
// authorised-domain list on the project.
//
// This is the one difference from the iOS GoogleService-Info.plist, which is
// NOT committed: that one ships inside a signed binary nobody downloads, so
// keeping it out of a public repo costs nothing and saves a quota.
//
// Worth doing in the Google Cloud console: restrict this API key to HTTP
// referrers for the authorised domains, so a scraped copy cannot spend the
// project's free tier from somewhere else.
export const firebaseConfig = {
  apiKey: "AIzaSyBtaWA_msOhoa6pHcRubhkW5E794M19nRI",
  authDomain: "qcris-caminata.firebaseapp.com",
  projectId: "qcris-caminata",
  storageBucket: "qcris-caminata.firebasestorage.app",
  messagingSenderId: "898210117692",
  appId: "1:898210117692:web:9fd2c0e72d918ad6bfeb39",
};
