class ContentSingle
    attr_accessor :base, :filename, :date, :body, :data, :type, :slug

    def initialize(base, filename)
        self.base = base
        self.filename = filename

        self.slug = "" # If left blank will Hugo handle it automatically with setting in Config file?
        self.date = Date.now
        # self.contentType =

        self.data = {}
        self.body = ""

    end
end
