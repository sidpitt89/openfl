import Application from "openfl/display/Application";
import * as assert from "assert";


describe ("ES6 | Application", function () {
	
	
	it ("new", function () {
		
		// TODO: Confirm functionality
		
		var application = new Application ();
		var exists = application;
		
		assert.notEqual (exists, null);
		
	});
	
	
});