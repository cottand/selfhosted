package module

component Home(lights []light, listFailed bool) {
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
					padding: 0.75rem 1rem;
					margin-bottom: 0.5rem;
					border-radius: 0.5rem;
					background: #eee;
				}
				.light.on {
					background: #ffe9a8;
				}
				.row {
					display: flex;
					align-items: center;
					justify-content: space-between;
				}
				.toggle {
					width: 3.5rem;
					height: 2rem;
					border: none;
					border-radius: 1rem;
					background: #bbb;
					position: relative;
					cursor: pointer;
				}
				.toggle::after {
					content: "";
					position: absolute;
					top: 0.25rem;
					left: 0.25rem;
					width: 1.5rem;
					height: 1.5rem;
					border-radius: 50%;
					background: white;
					transition: left 0.15s;
				}
				.toggle.on {
					background: #e0a800;
				}
				.toggle.on::after {
					left: 1.75rem;
				}
				.toggle:disabled {
					opacity: 0.4;
					cursor: not-allowed;
				}
				.brightness {
					display: flex;
					align-items: center;
					gap: 0.75rem;
					margin-top: 0.5rem;
				}
				.brightness input {
					flex: 1;
				}
				.brightness output {
					min-width: 3rem;
					text-align: right;
				}
				@media (min-width: 50rem) {
					body {
						max-width: 46rem;
					}
					.plan {
						position: relative;
						aspect-ratio: 800 / 1094;
						background: url("/floorplan.svg") center / contain no-repeat;
					}
					.light {
						position: absolute;
						box-sizing: border-box;
						width: 9rem;
						margin: 0;
						padding: 0.5rem 0.6rem;
						transform: translate(-50%, -50%);
						box-shadow: 0 1px 4px rgb(0 0 0 / 30%);
					}
					.brightness output {
						min-width: 2.5rem;
					}
					.brightness input {
						min-width: 0;
					}
					#light-plug103 {
						left: 10%;
						top: 34.7%;
					}
					#light-rgb105 {
						width: 11rem;
						left: 65%;
						top: 63.1%;
					}
					#light-plug104 {
						left: 89.6%;
						top: 63.3%;
					}
					#light-rgb108 {
						width: 11rem;
						left: 12.5%;
						top: 81.8%;
					}
					#light-plug106 {
						left: 30%;
						top: 89.6%;
					}
				}
			</style>
		</head>
		<body>
			<h1>Lights</h1>
			{ if listFailed {
				<p>Could not load lights.</p>
			} }
			<div class="plan">
				{ for _, l := range lights {
					<LightRow l={l}/>
				} }
			</div>
			<script>
				let draggedRow = null;
				let pendingRow = null;

				function applyRow(row) {
					document.getElementById(row.id)?.replaceWith(row);
				}

				document.addEventListener("pointerdown", (event) => {
					if (event.target.matches("input[type=range]")) {
						draggedRow = event.target.closest(".light").id;
					}
				});

				function endDrag() {
					// runs after the slider's change event, which needs the slider to still be there
					setTimeout(() => {
						draggedRow = null;
						if (pendingRow) {
							applyRow(pendingRow);
							pendingRow = null;
						}
					});
				}
				document.addEventListener("pointerup", endDrag);
				document.addEventListener("pointercancel", endDrag);

				new EventSource("/lights/events").addEventListener("light", (event) => {
					const template = document.createElement("template");
					template.innerHTML = event.data;
					const row = template.content.firstElementChild;
					if (row.id === draggedRow) {
						pendingRow = row;
					} else {
						applyRow(row);
					}
				});
			</script>
		</body>
	</html>
}

component LightRow(l light) {
	<div id={ "light-" + l.ID } class={ "light", "on": l.Known && l.On }>
		<div class="row">
			<div>
				<strong>{l.ID}</strong>
				<div>
					{ if !l.Known {
						unknown
					} else if !l.On {
						off
					} else if l.Dimmable {
						on · {l.Brightness}%
					} else {
						on
					} }
				</div>
			</div>
			<form method="post" action={ "/lights/" + l.ID }>
				<button
					type="submit"
					name="on"
					value={l.NextOn()}
					class={ "toggle", "on": l.Known && l.On }
					aria-pressed={l.Pressed()}
					aria-label={ "Toggle " + l.ID }
					disabled={!l.Known}
				></button>
			</form>
		</div>
		{ if l.Dimmable && l.Known {
			<form class="brightness" method="post" action={ "/lights/" + l.ID }>
				<input
					type="range"
					name="brightness"
					min="1"
					max="100"
					value={l.Brightness}
					aria-label={ "Brightness of " + l.ID }
					oninput=js`this.nextElementSibling.value = this.value + '%'`
					onchange=js`this.form.requestSubmit()`
				/>
				<output>{l.Brightness}%</output>
			</form>
		} }
	</div>
}
