package module

component Home(lights []light) {
	<!DOCTYPE html>
	<html lang="en">
		<head>
			<meta charset="utf-8"/>
			<meta name="viewport" content="width=device-width, initial-scale=1"/>
			<title>Home</title>
			<style>
				body {
					font-family: system-ui, sans-serif;
					max-width: 32rem;
					margin: 2rem auto;
					padding: 0 1rem;
				}
				.light {
					display: flex;
					align-items: center;
					justify-content: space-between;
					padding: 0.75rem 1rem;
					margin-bottom: 0.5rem;
					border-radius: 0.5rem;
					background: #eee;
				}
				.light.on {
					background: #ffe9a8;
				}
				.light form {
					display: flex;
					gap: 0.5rem;
				}
				button {
					font-size: 1rem;
					padding: 0.4rem 0.9rem;
				}
			</style>
		</head>
		<body>
			<h1>Lights</h1>
			{ for _, l := range lights {
				<LightRow l={l}/>
			} }
		</body>
	</html>
}

component LightRow(l light) {
	<div class={ "light", "on": l.Known && l.On }>
		<div>
			<strong>{l.ID}</strong>
			<div>
				{ if !l.Known {
					unknown
				} else if l.On {
					on
				} else {
					off
				} }
			</div>
		</div>
		<form method="post" action={ "/lights/" + l.ID }>
			<button type="submit" name="on" value="true">On</button>
			<button type="submit" name="on" value="false">Off</button>
		</form>
	</div>
}
