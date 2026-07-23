//=============================================================================
// Thin localStorage wrappers (DOM-free enough to mock in Node).
// Extracted from lodeRunner.storage.js for characterization tests.
//=============================================================================

function setStorage(key, value)
{
	if (typeof (window.localStorage) != 'undefined') {
		window.localStorage.setItem(key, value);
	}
}

function getStorage(key)
{
	var value = null;
	if (typeof (window.localStorage) != 'undefined') {
		value = window.localStorage.getItem(key);
	}
	return value;
}

function clearStorage(key)
{
	if (typeof (window.localStorage) != 'undefined') {
		window.localStorage.removeItem(key);
	}
}
