module.exports = {
  'Title' : function (client) {
    client
      .url('http://127.0.0.1:1337')
      .waitForElementVisible('body', 1000)
      .assert.title('127.0.0.1 – Just another WordPress site')
      .end();
  }
};
