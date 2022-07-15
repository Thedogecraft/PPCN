
	return !window.BDFDB_Global || (!window.BDFDB_Global.loaded && !window.BDFDB_Global.started) ? class {
		getName () {return config.info.name;}
		getAuthor () {return config.info.author;}
		getVersion () {return config.info.version;}
		getDescription () {return `The Library Plugin needed for ${config.info.name} is missing. Open the Plugin Settings to download it. \n\n${config.info.description}`;}
		
		downloadLibrary () {
			require("request").get("https://mwittrien.github.io/BetterDiscordAddons/Library/0BDFDB.plugin.js", (e, r, b) => {
				if (!e && b && r.statusCode == 200) require("fs").writeFile(require("path").join(BdApi.Plugins.folder, "0BDFDB.plugin.js"), b, _ => BdApi.showToast("Finished downloading BDFDB Library", {type: "success"}));
				else BdApi.alert("Error", "Could not download BDFDB Library Plugin. Try again later or download it manually from GitHub: https://mwittrien.github.io/downloader/?library");
			});
		}
		
		load () {
			if (!window.BDFDB_Global || !Array.isArray(window.BDFDB_Global.pluginQueue)) window.BDFDB_Global = Object.assign({}, window.BDFDB_Global, {pluginQueue: []});
			if (!window.BDFDB_Global.downloadModal) {
				window.BDFDB_Global.downloadModal = true;
				BdApi.showConfirmationModal("Library Missing", `The Library Plugin needed for ${config.info.name} is missing. Please click "Download Now" to install it.`, {
					confirmText: "Download Now",
					cancelText: "Cancel",
					onCancel: _ => {delete window.BDFDB_Global.downloadModal;},
					onConfirm: _ => {
						delete window.BDFDB_Global.downloadModal;
						this.downloadLibrary();
					}
				});
			}
			if (!window.BDFDB_Global.pluginQueue.includes(config.info.name)) window.BDFDB_Global.pluginQueue.push(config.info.name);
		}
		start () {this.load();}
		stop () {}
		getSettingsPanel () {
			let template = document.createElement("template");
			template.innerHTML = `<div style="color: var(--header-primary); font-size: 16px; font-weight: 300; white-space: pre; line-height: 22px;">The Library Plugin needed for ${config.info.name} is missing.\nPlease click <a style="font-weight: 500;">Download Now</a> to install it.</div>`;
			template.content.firstElementChild.querySelector("a").addEventListener("click", this.downloadLibrary);
			return template.content.firstElementChild;
		}
	} : (([Plugin, BDFDB]) => {
		var _this;
		
		var list, header;
		
		var loading, cachedPlugins, grabbedPlugins, updateInterval;
		var searchString, searchTimeout, forcedSort, forcedOrder, showOnlyOutdated;
		
		var favorites = [];
		
		const pluginStates = {
			INSTALLED: 0,
			OUTDATED: 1,
			DOWNLOADABLE: 2
		};
		const buttonData = {
			INSTALLED: {
				backgroundColor: "var(--bdfdb-green)",
				icon: "CHECKMARK",
				text: "installed"
			},
			OUTDATED: {
				backgroundColor: "var(--bdfdb-red)",
				icon: "CLOSE",
				text: "outdated"
			},
			DOWNLOADABLE: {
				backgroundColor: "var(--bdfdb-blurple)",
				icon: "DOWNLOAD",
				text: "download"
			}
		};
		const reverseSorts = [
			"RELEASEDATE", "DOWNLOADS", "LIKES", "FAV"
		];
		const sortKeys = {
			NAME:			"Name",
			AUTHORNAME:		"Author",
			VERSION:		"Version",
			DESCRIPTION:	"Description",
			RELEASEDATE:	"Release Date",
			STATE:			"Update State",
			DOWNLOADS:		"Downloads",
			LIKES:			"Likes",
			FAV:			"Favorites"
		};
		const orderKeys = {
			ASC:			"ascending",
			DESC:			"descending"
		};
		
		const pluginRepoIcon = `<svg width="37" height="32" viewBox="0 0 37 32"><path fill="COLOR_1" d="m 0,0 v 32 h 8.1672381 v -9.355469 h 4.7914989 c 7.802754,0 11.77368,-5.650788 11.77368,-11.345703 C 24.732417,5.6491106 20.8074,0 12.913386,0 Z m 8.1672381,7.5488281 h 4.7461479 c 4.928055,-0.045198 4.928055,7.9534009 0,7.9082029 H 8.1672381 Z"/><path fill="COLOR_2" d="M 23.173828 0 C 26.168987 2.3031072 27.920961 5.6614952 28.433594 9.2128906 C 29.159183 10.362444 29.181906 11.885963 28.511719 13.064453 C 28.098967 17.002739 26.191156 20.761973 22.810547 23.197266 L 29.287109 32 L 37 32 L 37 28.941406 L 30.65625 21.017578 C 34.580442 19.797239 37 16.452154 37 10.53125 C 36.81748 3.0284249 31.662 0 25 0 L 23.173828 0 z M 20.34375 24.603516 C 18.404231 25.464995 16.135462 25.970703 13.521484 25.970703 L 12.085938 25.970703 L 12.085938 32 L 20.34375 32 L 20.34375 24.603516 z"/></svg>`;
		
		const RepoListComponent = class PluginList extends BdApi.React.Component {
			componentDidMount() {
				list = this;
				BDFDB.TimeUtils.timeout(_ => {
					forcedSort = null;
					forcedOrder = null;
					showOnlyOutdated = false;
				}, 5000);
			}
			componentWillUnmount() {
				list = null;
			}
			filterPlugins() {
				let plugins = grabbedPlugins.map(plugin => {
					const installedPlugin = _this.getInstalledPlugin(plugin);
					const state = installedPlugin ? (plugin.version && BDFDB.NumberUtils.compareVersions(plugin.version, _this.getString(installedPlugin.version)) ? pluginStates.OUTDATED : pluginStates.INSTALLED) : pluginStates.DOWNLOADABLE;
					return Object.assign(plugin, {
						search: [plugin.name, plugin.version, plugin.authorname, plugin.description, plugin.tags].flat(10).filter(n => typeof n == "string").join(" ").toUpperCase(),
						description: plugin.description || "No Description found",
						fav: favorites.includes(plugin.id) && 1,
						new: state == pluginStates.DOWNLOADABLE && !cachedPlugins.includes(plugin.id) && 1,
						state: state
					});
				});
				if (!this.props.updated)		plugins = plugins.filter(plugin => plugin.state != pluginStates.INSTALLED);
				if (!this.props.outdated)		plugins = plugins.filter(plugin => plugin.state != pluginStates.OUTDATED);
				if (!this.props.downloadable)	plugins = plugins.filter(plugin => plugin.state != pluginStates.DOWNLOADABLE);
				if (searchString) 	{
					let usedSearchString = searchString.toUpperCase();
					let spacelessUsedSearchString = usedSearchString.replace(/\s/g, "");
					plugins = plugins.filter(plugin => plugin.search.indexOf(usedSearchString) > -1 || plugin.search.indexOf(spacelessUsedSearchString) > -1);
				}
				
				BDFDB.ArrayUtils.keySort(plugins, this.props.sortKey.toLowerCase());
				if (this.props.orderKey == "DESC") plugins.reverse();
				if (reverseSorts.includes(this.props.sortKey)) plugins.reverse();
				return plugins;
			}
			render() {
				let automaticLoading = BDFDB.BDUtils.getSettings(BDFDB.BDUtils.settingsIds.automaticLoading);
				if (!this.props.tab) this.props.tab = "Plugins";
				
				this.props.entries = (!loading.is && grabbedPlugins.length ? this.filterPlugins() : []).map(plugin => BDFDB.ReactUtils.createElement(RepoCardComponent, {
					data: plugin
				})).filter(n => n);
				
				BDFDB.TimeUtils.timeout(_ => {
					if (!loading.is && header && this.props.entries.length != header.props.amount) {
						header.props.amount = this.props.entries.length;
						BDFDB.ReactUtils.forceUpdate(header);
					}
				});
				
				return [
					BDFDB.ReactUtils.createElement(BDFDB.LibraryComponents.ModalComponents.ModalTabContent, {
						tab: "Plugins",
						open: this.props.tab == "Plugins",
						render: false,
						children: loading.is ? BDFDB.ReactUtils.createElement(BDFDB.LibraryComponents.Flex, {
							direction: BDFDB.LibraryComponents.Flex.Direction.VERTICAL,
							justify: BDFDB.LibraryComponents.Flex.Justify.CENTER,
							style: {marginTop: "50%"},
							children: [
								BDFDB.ReactUtils.createElement(BDFDB.LibraryComponents.Spinner, {
									type: BDFDB.LibraryComponents.Spinner.Type.WANDERING_CUBES
								}),
								BDFDB.ReactUtils.createElement(BDFDB.LibraryComponents.TextElement, {
									className: BDFDB.disCN.margintop20,
									style: {textAlign: "center"},
									children: `${BDFDB.LanguageUtils.LibraryStringsFormat("loading", "Plugin Repo")} - ${BDFDB.LanguageUtils.LibraryStrings.please_wait}`
								})
							]
						}) : BDFDB.ReactUtils.createElement("div", {
							className: BDFDB.disCN.discoverycards,
							children: this.props.entries
						})
					}),
					BDFDB.ReactUtils.createElement(BDFDB.LibraryComponents.ModalComponents.ModalTabContent, {
						tab: BDFDB.LanguageUtils.LanguageStrings.SETTINGS,
						open: this.props.tab == BDFDB.LanguageUtils.LanguageStrings.SETTINGS,
						render: false,
						children: [
							BDFDB.ReactUtils.createElement(BDFDB.LibraryComponents.SettingsPanelList, {
								title: "Show following Plugins",
								children: Object.keys(_this.defaults.filters).map(key => BDFDB.ReactUtils.createElement(BDFDB.LibraryComponents.SettingsSaveItem, {
									type: "Switch",
									plugin: _this,
									keys: ["filters", key],
									label: _this.defaults.filters[key].description,
									value: _this.settings.filters[key],
									onChange: value => {
										this.props[key] = _this.settings.filters[key] = value;
										BDFDB.ReactUtils.forceUpdate(this);
									}
								}))
							}),
							Object.keys(_this.defaults.general).map(key => BDFDB.ReactUtils.createElement(BDFDB.LibraryComponents.SettingsSaveItem, {
								type: "Switch",
								plugin: _this,
								keys: ["general", key],
								label: _this.defaults.general[key].description,
								note: key == "rnmStart" && !automaticLoading && "Automatic Loading has to be enabled",
								disabled: key == "rnmStart" && !automaticLoading,
								value: _this.settings.general[key],
								onChange: value => {
									_this.settings.general[key] = value;
									BDFDB.ReactUtils.forceUpdate(this);
								}
							})),
							!automaticLoading && BDFDB.ReactUtils.createElement(BDFDB.LibraryComponents.Flex, {
								className: BDFDB.disCN.marginbottom20,
								children: BDFDB.ReactUtils.createElement("div", {
									className: BDFDB.disCNS.settingsrowtitle + BDFDB.disCNS.settingsrowtitledefault + BDFDB.disCN.cursordefault,
									children: "To experience Plugin Repo in the best way. I would recommend you to enable BD's intern Automatic-Loading Feature, that way all downloaded Files are loaded into Discord without the need to reload."
								})
							})
						].flat(10).filter(n => n)
					})
				];
			}
		};
		
		const RepoCardComponent = class PluginCard extends BdApi.React.Component {
			render() {
				if (this.props.data.thumbnailUrl && !this.props.data.thumbnailChecked) {
					if (!window.Buffer) this.props.data.thumbnailChecked = true;
					else BDFDB.LibraryRequires.request(this.props.data.thumbnailUrl, {encoding: null}, (error, response, body) => {
						if (response && response.headers["content-type"] && response.headers["content-type"] == "image/gif") {
							const throwAwayImg = new Image(), instance = this;
							throwAwayImg.onload = function() {
								const canvas = document.createElement("canvas");
								canvas.getContext("2d").drawImage(throwAwayImg, 0, 0, canvas.width = this.width, canvas.height = this.height);
								try {
									const oldUrl = instance.props.data.thumbnailUrl;
									instance.props.data.thumbnailUrl = canvas.toDataURL("image/png");
									instance.props.data.thumbnailGifUrl = oldUrl;
									instance.props.data.thumbnailChecked = true;
									BDFDB.ReactUtils.forceUpdate(instance);
								}
								catch (err) {
									instance.props.data.thumbnailChecked = true;
									BDFDB.ReactUtils.forceUpdate(instance);
								}
							};
							throwAwayImg.onerror = function() {
								instance.props.data.thumbnailChecked = true;
								BDFDB.ReactUtils.forceUpdate(instance);
							};
							throwAwayImg.src = "data:" + response.headers["content-type"] + ";base64," + (new Buffer(body).toString("base64"));
						}
						else {
							this.props.data.thumbnailChecked = true;
							BDFDB.ReactUtils.forceUpdate(this);
						}
					});
				}
				return BDFDB.ReactUtils.createElement("div", {
					className: BDFDB.disCN.discoverycard,
					children: [
						BDFDB.ReactUtils.createElement("div", {
							className: BDFDB.disCN.discoverycardheader,
							children: [
								BDFDB.ReactUtils.createElement("div", {
									className: BDFDB.disCN.discoverycardcoverwrapper,
									children: [
										this.props.data.thumbnailUrl && this.props.data.thumbnailChecked && BDFDB.ReactUtils.createElement("img", {
											className: BDFDB.disCN.discoverycardcover,
											src: this.props.data.thumbnailUrl,
											onMouseEnter: this.props.data.thumbnailGifUrl && (e => e.target.src = this.props.data.thumbnailGifUrl),
											onMouseLeave: this.props.data.thumbnailGifUrl && (e => e.target.src = this.props.data.thumbnailUrl),
											onClick: _ => {
												const url = this.props.data.thumbnailGifUrl || this.props.data.thumbnailUrl;
												const img = document.createElement("img");
												img.addEventListener("load", function() {
													BDFDB.LibraryModules.ModalUtils.openModal(modalData => {
														return BDFDB.ReactUtils.createElement(BDFDB.LibraryComponents.ModalComponents.ModalRoot, Object.assign({
															className: BDFDB.disCN.imagemodal
														}, modalData, {
															size: BDFDB.LibraryComponents.ModalComponents.ModalSize.DYNAMIC,
															"aria-label": BDFDB.LanguageUtils.LanguageStrings.IMAGE,
															children: BDFDB.ReactUtils.createElement(BDFDB.LibraryComponents.ImageModal, {
																animated: false,
																src: url,
																original: url,
																width: this.width,
																height: this.height,
																className: BDFDB.disCN.imagemodalimage,
																shouldAnimate: true,
																renderLinkComponent: props => BDFDB.ReactUtils.createElement(BDFDB.LibraryComponents.Anchor, props)
															})
														}), true);
													});
												});
												img.src = url;
											}
										}),
										this.props.data.new && BDFDB.ReactUtils.createElement(BDFDB.LibraryComponents.Badges.TextBadge, {
											className: BDFDB.disCN.discoverycardcoverbadge,
											style: {
												borderRadius: 3,
												textTransform: "uppercase",
												background: BDFDB.DiscordConstants.Colors.STATUS_YELLOW
											},
											text: BDFDB.LanguageUtils.LanguageStrings.NEW
										})
									]
								}),
								BDFDB.ReactUtils.createElement(class extends BDFDB.ReactUtils.Component {
									render() {
										return BDFDB.ReactUtils.createElement("div", {
											className: BDFDB.disCN.discoverycardiconwrapper,
											children: this.props.data.author && this.props.data.author.discord_avatar_hash && this.props.data.author.discord_snowflake && !this.props.data.author.discord_avatar_failed ? BDFDB.ReactUtils.createElement("img", {
												className: BDFDB.DOMUtils.formatClassName(BDFDB.disCN.discoverycardicon, !this.props.data.author.discord_avatar_loaded && BDFDB.disCN.discoverycardiconloading),
												src: `https://cdn.discordapp.com/avatars/${this.props.data.author.discord_snowflake}/${this.props.data.author.discord_avatar_hash}.webp?size=128`,
												onLoad: _ => {
													this.props.data.author.discord_avatar_loaded = true;
													BDFDB.ReactUtils.forceUpdate(this);
												},
												onError: _ => {
													this.props.data.author.discord_avatar_failed = true;
													BDFDB.ReactUtils.forceUpdate(this);
												}
											}) : BDFDB.ReactUtils.createElement("div", {
												className: BDFDB.disCN.discoverycardicon,
												children: BDFDB.ReactUtils.createElement(BDFDB.LibraryComponents.SvgIcon, {
													nativeClass: true,
													iconSVG: `<svg width="100%" height="100%" viewBox="0 0 24 24"><path fill="currentColor" d="${BDFDB.ArrayUtils.is(this.props.data.tags) && this.props.data.tags.includes("library") ? "m 7.3125,2.625 c -0.3238672,0 -0.5859375,0.2620703 -0.5859375,0.5859375 V 14.929687 c 0,0.323868 0.2620703,0.585938 0.5859375,0.585938 2.710313,0 3.840547,1.498711 4.101563,1.914062 V 3.9905599 C 10.603047,3.3127865 9.3007813,2.625 7.3125,2.625 Z M 4.96875,3.796875 c -0.3238672,0 -0.5859375,0.2620703 -0.5859375,0.5859375 V 17.273437 c 0,0.323868 0.2620703,0.585938 0.5859375,0.585938 h 5.30599 C 9.9465755,17.461602 9.0865625,16.6875 7.3125,16.6875 c -0.9692969,0 -1.7578125,-0.788516 -1.7578125,-1.757813 V 3.796875 Z m 9.375,0 c -0.662031,0 -1.266641,0.2287891 -1.757812,0.6005859 V 18.445312 c 0,-0.323281 0.262656,-0.585937 0.585937,-0.585937 h 5.859375 c 0.323868,0 0.585937,-0.26207 0.585937,-0.585938 V 4.3828125 c 0,-0.3238672 -0.262069,-0.5859375 -0.585937,-0.5859375 z M 2.5859375,4.96875 C 2.2620703,4.96875 2,5.2308203 2,5.5546875 V 19.617187 c 0,0.323868 0.2620703,0.585938 0.5859375,0.585938 H 9.171224 c 0.2420313,0.68207 0.892995,1.171875 1.656901,1.171875 h 2.34375 c 0.763906,0 1.414831,-0.489805 1.656901,-1.171875 h 6.585286 C 21.73793,20.203125 22,19.941055 22,19.617187 V 5.5546875 C 22,5.2308203 21.73793,4.96875 21.414062,4.96875 h -0.585937 v 12.304687 c 0,0.969297 -0.827578,1.757813 -1.796875,1.757813 H 13.656901 C 13.41487,19.71332 12.763907,20.203125 12,20.203125 c -0.763906,0 -1.414831,-0.489805 -1.656901,-1.171875 H 4.96875 c -0.9692968,0 -1.796875,-0.788516 -1.796875,-1.757813 V 4.96875 Z" : "m 11.470703,0.625 c -1.314284,0 -2.3808593,1.0666594 -2.3808592,2.3808594 V 4.4335938 H 5.2792969 c -1.0476168,0 -1.8945313,0.85855 -1.8945313,1.90625 v 3.6191406 h 1.4179688 c 1.41905,0 2.5722656,1.1512126 2.5722656,2.5703126 0,1.4191 -1.1532156,2.572266 -2.5722656,2.572265 H 3.375 v 3.619141 c 0,1.0477 0.8566801,1.904297 1.9042969,1.904297 h 3.6191406 v -1.427734 c 0,-1.4189 1.1532235,-2.572266 2.5722655,-2.572266 1.41905,0 2.570313,1.153366 2.570313,2.572266 V 20.625 h 3.61914 c 1.047626,0 1.90625,-0.856597 1.90625,-1.904297 v -3.810547 h 1.427735 c 1.314292,0 2.380859,-1.066559 2.380859,-2.380859 0,-1.3143 -1.066567,-2.38086 -2.380859,-2.380859 H 19.566406 V 6.3398438 c 0,-1.0477002 -0.858624,-1.90625 -1.90625,-1.90625 H 13.851562 V 3.0058594 c 0,-1.3142 -1.066568,-2.3808594 -2.380859,-2.3808594 z"}"/></svg>`
												})
											})
										});
									}
								}, this.props)
							]							
						}),
						BDFDB.ReactUtils.createElement("div", {
							className: BDFDB.disCN.discoverycardinfo,
							children: [
								BDFDB.ReactUtils.createElement("div", {
									className: BDFDB.disCN.discoverycardtitle,
									children: [
										BDFDB.ReactUtils.createElement("div", {
											className: BDFDB.disCN.discoverycardname,
											children: this.props.data.name
										}),
										this.props.data.latestSourceUrl && 
										BDFDB.ReactUtils.createElement(BDFDB.LibraryComponents.TooltipContainer, {
											text: BDFDB.LanguageUtils.LanguageStrings.SCREENSHARE_SOURCE,
											children: BDFDB.ReactUtils.createElement(BDFDB.LibraryComponents.Clickable, {
												className: BDFDB.disCN.discoverycardtitlebutton,
												children: BDFDB.ReactUtils.createElement(BDFDB.LibraryComponents.SvgIcon, {
													nativeClass: true,
													width: 16,
													height: 16,
													name: BDFDB.LibraryComponents.SvgIcon.Names.GITHUB
												})
											}),
											onClick: _ => BDFDB.DiscordUtils.openLink(this.props.data.latestSourceUrl)
										}),
										BDFDB.ReactUtils.createElement(BDFDB.LibraryComponents.FavButton, {
											className: BDFDB.disCN.discoverycardtitlebutton,
											isFavorite: this.props.data.fav,
											onClick: value => {
												this.props.data.fav = value && 1;
												if (value) favorites.push(this.props.data.id);
												else BDFDB.ArrayUtils.remove(favorites, this.props.data.id, true);
												BDFDB.DataUtils.save(BDFDB.ArrayUtils.numSort(favorites).join(" "), _this, "favorites");
											}
										})
									]
								}),
								BDFDB.ReactUtils.createElement("div", {
									className: BDFDB.disCN.discoverycardauthor,
									children: `by ${this.props.data.authorname}`
								}),
								BDFDB.ReactUtils.createElement(BDFDB.LibraryComponents.Scrollers.Thin, {
									className: BDFDB.disCN.discoverycarddescription,
									children: this.props.data.description
								}),
								BDFDB.ReactUtils.createElement("div", {
									className: BDFDB.disCN.discoverycardfooter,
									children: [
										BDFDB.ArrayUtils.is(this.props.data.tags) && this.props.data.tags.length && BDFDB.ReactUtils.createElement("div", {
											className: BDFDB.disCN.discoverycardtags,
											children: this.props.data.tags.map(tag => BDFDB.ReactUtils.createElement(BDFDB.LibraryComponents.Badges.TextBadge, {
												className: BDFDB.disCN.discoverycardtag,
												style: {background: "var(--background-accent)"},
												text: tag
											}))
										}),
										BDFDB.ReactUtils.createElement("div", {
											className: BDFDB.disCN.discoverycardcontrols,
											children: [
												BDFDB.ReactUtils.createElement("div", {
													className: BDFDB.disCN.discoverycardstats,
													children: [
														BDFDB.ReactUtils.createElement("div", {
															className: BDFDB.disCN.discoverycardstat,
															children: [
																BDFDB.ReactUtils.createElement(BDFDB.LibraryComponents.SvgIcon, {
																	className: BDFDB.disCN.discoverycardstaticon,
																	width: 16,
																	height: 16,
																	name: BDFDB.LibraryComponents.SvgIcon.Names.DOWNLOAD
																}),
																this.props.data.downloads
															]
														}),
														BDFDB.ReactUtils.createElement("div", {
															className: BDFDB.disCN.discoverycardstat,
															children: [
																BDFDB.ReactUtils.createElement(BDFDB.LibraryComponents.SvgIcon, {
																	className: BDFDB.disCN.discoverycardstaticon,
																	width: 16,
																	height: 16,
																	name: BDFDB.LibraryComponents.SvgIcon.Names.HEART
																}),
																this.props.data.likes
															]
														})
													]
												}),
												BDFDB.ReactUtils.createElement(RepoCardDownloadButtonComponent, {
													...buttonData[(Object.entries(pluginStates).find(n => n[1] == this.props.data.state) || [])[0]],
													installed: this.props.data.state == pluginStates.INSTALLED,
													outdated: this.props.data.state == pluginStates.OUTDATED,
													onDownload: _ => {
														if (this.props.downloading) return;
														this.props.downloading = true;
														let loadingToast = BDFDB.NotificationUtils.toast(`${BDFDB.LanguageUtils.LibraryStringsFormat("loading", this.props.data.name)} - ${BDFDB.LanguageUtils.LibraryStrings.please_wait}`, {timeout: 0, ellipsis: true});
														BDFDB.LibraryRequires.request(this.props.data.rawSourceUrl, (error, response, body) => {
															if (error) {
																delete this.props.downloading;
																loadingToast.close();
																BDFDB.NotificationUtils.toast(BDFDB.LanguageUtils.LibraryStringsFormat("download_fail", `Plugin "${this.props.data.name}"`), {type: "danger"});
															}
															else {
																BDFDB.LibraryRequires.fs.writeFile(BDFDB.LibraryRequires.path.join(BDFDB.BDUtils.getPluginsFolder(), this.props.data.rawSourceUrl.split("/").pop()), body, error2 => {
																	delete this.props.downloading;
																	loadingToast.close();
																	if (error2) BDFDB.NotificationUtils.toast(BDFDB.LanguageUtils.LibraryStringsFormat("save_fail", `Plugin "${this.props.data.name}"`), {type: "danger"});
																	else {
																		BDFDB.NotificationUtils.toast(BDFDB.LanguageUtils.LibraryStringsFormat("save_success", `Plugin "${this.props.data.name}"`), {type: "success"});
																		if (_this.settings.general.rnmStart) BDFDB.TimeUtils.timeout(_ => {
																			if (this.props.data.state == pluginStates.INSTALLED && BDFDB.BDUtils.isPluginEnabled(this.props.data.name) == false) {
																				BDFDB.BDUtils.enablePlugin(this.props.data.name, false);
																				BDFDB.LogUtils.log(BDFDB.LanguageUtils.LibraryStringsFormat("toast_plugin_started", this.props.data.name), _this);
																			}
																		}, 3000);
																		this.props.data.state = pluginStates.INSTALLED;
																		BDFDB.ReactUtils.forceUpdate(this);
																	}
																});
															}
														});
													},
													onDelete: _ => {
														if (this.props.deleting) return;
														this.props.deleting = true;
														BDFDB.LibraryRequires.fs.unlink(BDFDB.LibraryRequires.path.join(BDFDB.BDUtils.getPluginsFolder(), this.props.data.rawSourceUrl.split("/").pop()), error => {
															delete this.props.deleting;
															if (error) BDFDB.NotificationUtils.toast(BDFDB.LanguageUtils.LibraryStringsFormat("delete_fail", `Plugin "${this.props.data.name}"`), {type: "danger"});
															else {
																BDFDB.NotificationUtils.toast(BDFDB.LanguageUtils.LibraryStringsFormat("delete_success", `Plugin "${this.props.data.name}"`));
																this.props.data.state = pluginStates.DOWNLOADABLE;
																BDFDB.ReactUtils.forceUpdate(this);
															}
														});
													}
												})
											]
										})
									]
								})
							]
						})
					]
				});
			}
		};
		
		const RepoCardDownloadButtonComponent = class PluginCardDownloadButton extends BdApi.React.Component {
			render() {
				const backgroundColor = this.props.doDelete ? buttonData.OUTDATED.backgroundColor : this.props.doUpdate ? buttonData.INSTALLED.backgroundColor : this.props.backgroundColor;
				return BDFDB.ReactUtils.createElement("button", {
					className: BDFDB.disCN.discoverycardbutton,
					style: {backgroundColor: BDFDB.DiscordConstants.Colors[backgroundColor] || backgroundColor},
					children: [
						BDFDB.ReactUtils.createElement(BDFDB.LibraryComponents.SvgIcon, {
							className: BDFDB.disCN.discoverycardstaticon,
							width: 16,
							height: 16,
							name: this.props.doDelete ? BDFDB.LibraryComponents.SvgIcon.Names.TRASH : this.props.doUpdate ? BDFDB.LibraryComponents.SvgIcon.Names.DOWNLOAD : BDFDB.LibraryComponents.SvgIcon.Names[this.props.icon]
						}),
						this.props.doDelete ? BDFDB.LanguageUtils.LanguageStrings.APPLICATION_CONTEXT_MENU_UNINSTALL : this.props.doUpdate ? BDFDB.LanguageUtils.LanguageStrings.GAME_ACTION_BUTTON_UPDATE : (BDFDB.LanguageUtils.LibraryStringsCheck[this.props.text] ? BDFDB.LanguageUtils.LibraryStrings[this.props.text] : BDFDB.LanguageUtils.LanguageStrings[this.props.text])
					],
					onClick: _ => {
						if (this.props.doDelete) typeof this.props.onDelete == "function" && this.props.onDelete();
						else typeof this.props.onDownload == "function" && this.props.onDownload();
					},
					onMouseEnter: this.props.installed ? (_ => {
						this.props.doDelete = true;
						BDFDB.ReactUtils.forceUpdate(this);
					}) : this.props.outdated ? (_ => {
						this.props.doUpdate = true;
						BDFDB.ReactUtils.forceUpdate(this);
					}) : (_ => {}),
					onMouseLeave: this.props.installed ? (_ => {
						this.props.doDelete = false;
						BDFDB.ReactUtils.forceUpdate(this);
					}) : this.props.outdated ? (_ => {
						this.props.doUpdate = false;
						BDFDB.ReactUtils.forceUpdate(this);
					}) : (_ => {})
				});
			}
		};
		
		const RepoListHeaderComponent = class PluginListHeader extends BdApi.React.Component {
			componentDidMount() {
				header = this;
			}
			render() {
				if (!this.props.tab) this.props.tab = "Plugins";
				return BDFDB.ReactUtils.createElement("div", {
					className: BDFDB.disCN._repolistheader,
					children: [
						BDFDB.ReactUtils.createElement(BDFDB.LibraryComponents.Flex, {
							className: BDFDB.disCN.marginbottom4,
							align: BDFDB.LibraryComponents.Flex.Align.CENTER,
							children: [
								BDFDB.ReactUtils.createElement(BDFDB.LibraryComponents.Flex.Child, {
									grow: 1,
									shrink: 0,
									children: BDFDB.ReactUtils.createElement(BDFDB.LibraryComponents.FormComponents.FormTitle, {
										tag: BDFDB.LibraryComponents.FormComponents.FormTitle.Tags.H2,
										className: BDFDB.disCN.marginreset,
										children: `Plugin Repo — ${loading.is ? 0 : this.props.amount || 0}/${loading.is ? 0 : grabbedPlugins.length}`
									})
								}),
								BDFDB.ReactUtils.createElement(BDFDB.LibraryComponents.Flex.Child, {
									children: BDFDB.ReactUtils.createElement(BDFDB.LibraryComponents.SearchBar, {
										autoFocus: true,
										query: searchString,
										onChange: (value, instance) => {
											if (loading.is) return;
											BDFDB.TimeUtils.clear(searchTimeout);
											searchTimeout = BDFDB.TimeUtils.timeout(_ => {
												searchString = value.replace(/[<|>]/g, "");
												BDFDB.ReactUtils.forceUpdate(this, list);
											}, 1000);
										},
										onClear: instance => {
											if (loading.is) return;
											searchString = "";
											BDFDB.ReactUtils.forceUpdate(this, list);
										}
									})
								}),
								BDFDB.ReactUtils.createElement(BDFDB.LibraryComponents.Button, {
									size: BDFDB.LibraryComponents.Button.Sizes.TINY,
									children: BDFDB.LanguageUtils.LibraryStrings.check_for_updates,
									onClick: _ => {
										if (loading.is) return;
										loading = {is: false, timeout: null, amount: 0};
										_this.loadPlugins();
									}
								})
							]
						}),
						BDFDB.ReactUtils.createElement(BDFDB.LibraryComponents.Flex, {
							className: BDFDB.disCNS.tabbarcontainer + BDFDB.disCN.tabbarcontainerbottom,
							align: BDFDB.LibraryComponents.Flex.Align.CENTER,
							children: [
								BDFDB.ReactUtils.createElement(BDFDB.LibraryComponents.Flex.Child, {
									children: BDFDB.ReactUtils.createElement(BDFDB.LibraryComponents.TabBar, {
										className: BDFDB.disCN.tabbar,
										itemClassName: BDFDB.disCN.tabbaritem,
										type: BDFDB.LibraryComponents.TabBar.Types.TOP,
										selectedItem: this.props.tab,
										items: [{value: "Plugins"}, {value: BDFDB.LanguageUtils.LanguageStrings.SETTINGS}],
										onItemSelect: value => {
											this.props.tab = list.props.tab = value;
                      END
		
})();
